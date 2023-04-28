function setup(varargin)
%SETUP compiles the package and try adding the package into the search path.
%
%   Let solvername be a string indicating a solver name, and options be
%   a structure indicating compilation options. Then setup can be called
%   in the following ways:
%
%   setup(solvername, options) compiles the solver specified by solvername with options
%   setup(solvername) compiles the solver specified by solvername
%   setup(options) compiles all the solvers with options
%
%   In addition, one can uninstall the package by calling
%
%   setup uninstall
%
%   or remove the compiled MEX files by calling
%
%   setup clean
%
%   REMARKS:
%
%   1. Since MEX is the standard way of calling Fortran code in MATLAB, you
%   need to have MEX properly configured for compile Fortran before using
%   the package. It is out of the scope of this package to help the users
%   to configure MEX.
%
%   If MEX is correctly configured, then the compilation will be done
%   automatically by this script.
%
%   2. At the end of this script, we will try saving the path of this package
%   to the search path. This can be done only if you have the permission to
%   write the following path-defining file:
%
%   fullfile(matlabroot, 'toolbox', 'local', 'pathdef.m')
%   NOTE: MATLAB MAY CHANGE THE LOCATION OF THIS FILE IN THE FUTURE
%
%   Otherwise, you CAN still use the package, except that you need to run
%   the startup.m script in the current directory each time you start a new
%   MATLAB session that needs the package. startup.m will not re-compile
%   the package but only add it into the search path.
%
%   ***********************************************************************
%   Authors:    Tom M. RAGONNEAU (tom.ragonneau@connect.polyu.hk)
%               and Zaikun ZHANG (zaikun.zhang@polyu.edu.hk)
%               Department of Applied Mathematics,
%               The Hong Kong Polytechnic University.
%
%   Dedicated to late Professor M. J. D. Powell FRS (1936--2015).
%   ***********************************************************************

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Attribute: public (can be called directly by users)
%
% Remarks
%
% 1. Remarks on the directory interfaces_private.
% Functions and MEX files in the directory interfaces_private are
% automatically available to functions in the directory interfaces, and
% to scripts called by the functions that reside in interfaces. They are
% not available to other functions/scripts unless interfaces_private is
% added to the search path.
%
% 2. Remarks on the 'files_with_wildcard' function.
% MATLAB R2015b does not handle wildcard (*) properly. For example, if
% we would like to removed all the .mod files under a directory specified
% by dirname, then the following would workd for MATLAB later than R2016a:
% delete(fullfile(dirname, '*.mod'));
% However, MATLAB R2015b would complain that it cannot find '*.mod'.
% The 'files_with_wildcard' function provides a workaround.
%
% TODO: None
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

COMPILE_CLASSICAL = true; %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% setup starts

% Check the version of MATLAB.
if verLessThan('matlab', '8.3') % MATLAB R2014a = MATLAB 8.3
    fprintf('\nSorry, this package does not support MATLAB R2013b or earlier releases.\n\n');
    return
end

% Interpret the input.
solver_list = {'uobyqa', 'newuoa', 'bobyqa', 'lincoa', 'cobyla'}; % Solvers to compile; by default, it contains all solvers
options = struct(); % Compilation options
wrong_input = false;
solver = 'ALL'; % The solver to compile specified by the user; by default, it is 'ALL', meaning all solvers
if nargin == 1
    if isa(varargin{1}, 'char') || isa(varargin{1}, 'string')
        solver = varargin{1};
    elseif isa(varargin{1}, 'struct') || isempty(varargin{1})
        options = varargin{1};
    else
        fprintf('\nThe input to setup should be a string and/or a structure.\n\n');
        wrong_input = true;
    end
elseif nargin == 2
    if (isa(varargin{1}, 'char') || isa(varargin{1}, 'string')) && (isa(varargin{2}, 'struct') || isempty(varargin{2}))
        solver = varargin{1};
        options = varargin{2};
    elseif (isa(varargin{2}, 'char') || isa(varargin{2}, 'string')) && (isa(varargin{1}, 'struct') || isempty(varargin{1}))
        solver = varargin{2};
        options = varargin{1};
    else
        fprintf('\nThe input to setup should be a string and/or a structure.\n\n');
        wrong_input = true;
    end
elseif nargin > 0
    fprintf('\nSetup accepts at most two inputs.\n\n');
    wrong_input = true;
end

solver = char(solver); % Cast solver to a character array; this is necessary if solver is a matlab string

% Remove the compiled MEX files if requested.
if strcmp(solver, 'clean')
    clean_mex;
    return;
end

% Uninstall the package if requested.
if strcmp(solver, 'uninstall')
    uninstall_pdfo;
    return;
end

% Decide which solver(s) to compile.
solver = solver(1:end-1);  % We expect to receive 'uobyqan', 'newuoan', ...; here we remove the 'n'
if ismember(solver, solver_list)
    solver_list = {solver};
elseif ~strcmpi(solver, 'ALL')
    fprintf('Unknown solver ''%s'' to compile.\n\n', solver);
    wrong_input = true;
end

% Exit if wrong input detected.
if wrong_input
    return
end

% Extract compilation options.
if isempty(options)
    options = struct();
end
opt_option = '-O';  % Optimize the object code; this is the default
debug_flag = (isfield(options, 'debug') && options.debug);
if debug_flag
    opt_option = '-g';  % Debug mode; -g disables MEX's behavior of optimizing built object code
end
% N.B.: -O and -g may lead to (slightly) different behaviors of the mexified code. This was observed
% on 2021-09-09 in a test of NEWUOA on the AKIVA problem of CUTEst. It was because the mexified code
% produced different results when it was supposed to evaluate COS(0.59843577329095299_DP) amid OTHER
% CALCULATIONS: with -O, the result was 0.82621783366991353; with -g, it became 0.82621783366991364.
% Bizarrely, if we write a short Fortran program to evaluate only COS(0.59843577329095299_DP),
% then the result is always 0.82621783366991364, regardless of -O or -g. No idea why.

% Detect whether we are running a 32-bit MATLAB, where maxArrayDim = 2^31-1, and then set ad_option
% accordingly. On a 64-bit MATLAB, maxArrayDim = 2^48-1 according to the document of MATLAB R2019a.
% !!! Make sure that everything is compiled with the SAME ad_option !!!
% !!! Otherwise, Segmentation Fault may occur !!!
[Architecture, maxArrayDim] = computer;
if any(strfind(Architecture, '64')) && log2(maxArrayDim) > 31
    ad_option = '-largeArrayDims';
else
    ad_option = '-compatibleArrayDims'; % This will also work in a 64-bit MATLAB
end

% Set MEX options.
mex_options = [{opt_option}, {ad_option}, '-silent'];

% Check whether MEX is properly configured.
fprintf('\nVerifying the set-up of MEX ... \n\n');
language = 'FORTRAN'; % Language to compile
mex_well_conf = mex_well_configured(language);
if mex_well_conf == 0
    fprintf('\nVerification FAILED.\n')
    fprintf('\nThe MEX of your MATLAB is not properly configured for compiling Fortran.');
    fprintf('\nPlease configure MEX before using this package. Try ''help mex'' for more information.\n\n');
    return
elseif mex_well_conf == -1
    fprintf('\nmex(''-setup'', ''%s'') runs successfully but we cannot verify that MEX works properly.', language);
    fprintf('\nWe will try to continue.\n\n');
else
    fprintf('\nMEX is correctly set up.\n\n');
end

% The full path of several directories.
cpwd = fileparts(mfilename('fullpath')); % Current directory
fsrc = fullfile(cpwd, 'fsrc'); % Directory of the Fortran source code
fsrc_intersection_form = fullfile(cpwd, 'fsrc/intersection_form'); % Directory of the intersection-form Fortran source code
fsrc_common_intersection_form = fullfile(fsrc_intersection_form, 'common'); % Directory of the common files
fsrc_classical = fullfile(cpwd, 'fsrc/classical'); % Directory of the classical Fortran source code
fsrc_classical_intersection_form = fullfile(cpwd, 'fsrc/classical/intersection_form'); % Directory of the intersection-form Fortran source code
matd = fullfile(cpwd, 'matlab'); % Matlab directory
gateways = fullfile(matd, 'mex_gateways'); % Directory of the MEX gateway files
gateways_intersection_form = fullfile(gateways, 'intersection_form');  % Directory of the intersection-form MEX gateway files
gateways_classical = fullfile(gateways_intersection_form, 'classical'); % Directory of the MEX gateway files for the classical Fortran code
interfaces = fullfile(matd, 'interfaces'); % Directory of the interfaces
interfaces_private = fullfile(interfaces, 'private'); % The private subdirectory of the interfaces
tests = fullfile(matd, 'tests'); % Directory containing some tests
tools = fullfile(matd, 'tools'); % Directory containing some tools, e.g., interform.m

% Name of the file that contains the list of Fortran files. There should be such a file in each
% Fortran source code directory, and the list should indicate the dependence among the files.
filelist = 'ffiles.txt';

% Generate the intersection-form Fortran source code
% We need to do this because MEX accepts only the (obselescent) fixed-form Fortran code on Windows.
% Intersection-form Fortran code can be compiled both as free form and as fixed form.
fprintf('Refactoring the Fortran code ... ');
addpath(tools);
interform(fsrc);
interform(fsrc_classical);
interform(gateways);
rmpath(tools);
fprintf('Done.\n\n');

% Clean up the directories fsrc and gateways before compilation.
% This is important especially if there was previously another
% compilation with a different ad_option. Without cleaning-up, the MEX
% files may be linked with wrong .mod or .o files, which can lead to
% serious errors including Segmentation Fault!
dir_list = {fsrc_common_intersection_form, gateways_intersection_form, gateways_classical, interfaces_private};
for idir = 1 : length(dir_list)
    mod_files = files_with_wildcard(dir_list{idir}, '*.mod');
    obj_files = [files_with_wildcard(dir_list{idir}, '*.o'), files_with_wildcard(dir_list{idir}, '*.obj')];
    cellfun(@(filename) delete(filename), [mod_files, obj_files]);
end

% Compilation starts
fprintf('Compilation starts. It may take some time ...\n');
cd(interfaces_private); % Change directory to interfaces_private; all the MEX files will output to this directory

try
% NOTE: Everything until 'catch' is conducted in interfaces_private.
% We use try ... catch so that we can change directory back to cpwd in
% case of an error.


    % Compilation of the common files. They are shared by all solvers. We compile them only once.
    % gateways_intersection_form/debug.F contains debugging subroutines tailored for MEX.
    copyfile(fullfile(gateways_intersection_form, 'debug.F'), fsrc_common_intersection_form);
    % ppf.h contains preprocessing directives. Set __DEBUGGING__ according to debug_flag.
    header_file = fullfile(fsrc_common_intersection_form, 'ppf.h');
    header_file_bak = fullfile(fsrc_common_intersection_form, 'ppf.h.bak');
    copyfile(header_file, header_file_bak);
    if debug_flag
        rep_str(header_file, '#define __DEBUGGING__ 0', '#define __DEBUGGING__ 1');
    else
        rep_str(header_file, '#define __DEBUGGING__ 1', '#define __DEBUGGING__ 0');
    end
    % Common Fortran source files.
    common_files = regexp(fileread(fullfile(fsrc_common_intersection_form, filelist)), '\n', 'split');
    common_files = strtrim(common_files(~cellfun(@isempty, common_files)));
    common_files = fullfile(fsrc_common_intersection_form, common_files);
    common_files = [common_files, fullfile(gateways_intersection_form, 'fmxapi.F'), fullfile(gateways_intersection_form, 'cbfun.F'), fullfile(gateways_classical, 'fmxcl.F')];
    % The loop below may be written in one line as follows:
    %mex(mex_options{:}, '-c', common_files{:}, '-outdir', fsrc_common_intersection_form);
    % But it does not work for some versions of MATLAB. This may be because the compilation above does
    % not respect the order of common_files{:}, which is critical due to the dependence among modules.
    for icf = 1 : length(common_files)
        mex(mex_options{:}, '-c', common_files{icf}, '-outdir', fsrc_common_intersection_form);
    end
    common_obj_files = [files_with_wildcard(fsrc_common_intersection_form, '*.o'), files_with_wildcard(fsrc_common_intersection_form, '*.obj')];

    % Compilation of function gethuge
    mex(mex_options{:}, '-output', 'gethuge', common_obj_files{:}, fullfile(gateways_intersection_form, 'gethuge.F'), '-outdir', interfaces_private);

    for isol = 1 : length(solver_list)

        solver = solver_list{isol};

        % Compilation of solver
        fprintf('Compiling %s ... ', solver);

        % Clean up the source file directory
        mod_files = files_with_wildcard(fullfile(fsrc_intersection_form, solver), '*.mod');
        obj_files = [files_with_wildcard(fullfile(fsrc_intersection_form, solver), '*.o'), files_with_wildcard(fullfile(fsrc_intersection_form, solver), '*.obj')];
        cellfun(@(filename) delete(filename), [mod_files, obj_files]);
        % Compile
        src_files = regexp(fileread(fullfile(fsrc_intersection_form, solver, filelist)), '\n', 'split');
        src_files = strtrim(src_files(~cellfun(@isempty, src_files)));
        src_files = fullfile(fsrc_intersection_form, solver, src_files);
        %mex(mex_options{:}, '-c', src_files{:}, '-outdir', fullfile(fsrc_intersection_form, solver));
        for isf = 1 : length(src_files)
            mex(mex_options{:}, '-c', src_files{isf}, '-outdir', fullfile(fsrc_intersection_form, solver));
        end
        obj_files = [common_obj_files, files_with_wildcard(fullfile(fsrc_intersection_form, solver), '*.o'), files_with_wildcard(fullfile(fsrc_intersection_form, solver), '*.obj')];
        mex(mex_options{:}, '-output', ['f', solver, 'n'], obj_files{:}, fullfile(gateways_intersection_form, [solver, '_mex.F']), '-outdir', interfaces_private);
        % Clean up the source file directory
        mod_files = files_with_wildcard(fullfile(fsrc_intersection_form, solver), '*.mod');
        obj_files = [files_with_wildcard(fullfile(fsrc_intersection_form, solver), '*.o'), files_with_wildcard(fullfile(fsrc_intersection_form, solver), '*.obj')];
        cellfun(@(filename) delete(filename), [mod_files, obj_files]);

  if (COMPILE_CLASSICAL) %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Compilation of the 'classical' version of solver
        % Clean up the source file directory
        mod_files = files_with_wildcard(fullfile(fsrc_classical, solver), '*.mod');
        obj_files = [files_with_wildcard(fullfile(fsrc_classical, solver), '*.o'), files_with_wildcard(fullfile(fsrc_classical, solver), '*.obj')];
        cellfun(@(filename) delete(filename), [mod_files, obj_files]);
        % Compile
        src_files = [files_with_wildcard(fullfile(fsrc_classical, solver), '*.f'), files_with_wildcard(fullfile(fsrc_classical, solver), '*.f90')];
        %mex(mex_options{:}, '-c', src_files{:}, '-outdir', fullfile(fsrc_classical, solver));
        for isf = 1 : length(src_files)
            mex(mex_options{:}, '-c', src_files{isf}, '-outdir', fullfile(fsrc_classical, solver));
        end
        obj_files = [common_obj_files, files_with_wildcard(fullfile(fsrc_classical, solver), '*.o'), files_with_wildcard(fullfile(fsrc_classical,solver), '*.obj')];
        mex(mex_options{:}, '-output', ['f', solver, 'n_classical'], obj_files{:}, fullfile(gateways_intersection_form, [solver, '_mex.F']), '-outdir', interfaces_private);
        % Clean up the source file directory
        mod_files = files_with_wildcard(fullfile(fsrc_classical, solver), '*.mod');
        obj_files = [files_with_wildcard(fullfile(fsrc_classical, solver), '*.o'), files_with_wildcard(fullfile(fsrc_classical, solver), '*.obj')];
        cellfun(@(filename) delete(filename), [mod_files, obj_files]);
  end

        fprintf('Done.\n');
    end

    % Clean up the .mod and .o files in fsrc_common_intersection_form.
    cellfun(@(filename) delete(filename), [common_obj_files, files_with_wildcard(fsrc_common_intersection_form, '*.mod')]);
    % Clean up the .mod files in interfaces_private.
    cellfun(@(filename) delete(filename), files_with_wildcard(interfaces_private, '*.mod'));

    % Remove the intersection-form Fortran files if we are not debugging.
    if ~debug_flag
        rmdir(fsrc_intersection_form, 's');
        rmdir(fsrc_classical_intersection_form, 's');
        rmdir(gateways_intersection_form, 's');
    end

catch exception % NOTE: Everything above 'catch' is conducted in interfaces_private.
    if exist(header_file_bak, 'file')  % Restore header_file
        movefile(header_file_bak, header_file);
    end
    cd(cpwd); % In case of an error, change directory back to cpwd
    rethrow(exception)
end

if exist(header_file_bak, 'file')  % Restore header_file
    movefile(header_file_bak, header_file);
end
cd(cpwd); % Compilation completes successfully; change directory back to cpwd

% Compilation ends
fprintf('Package compiled successfully!\n');

% Add interface (but not interfaces_private) to the search path
addpath(interfaces);

% Try saving path
path_saved = false;
orig_warning_state = warning;
warning('off', 'MATLAB:SavePath:PathNotSaved'); % Maybe we do not have the permission to save path.
if savepath == 0
    % SAVEPATH saves the current MATLABPATH in the path-defining file,
    % which is by default located at:
    % fullfile(matlabroot, 'toolbox', 'local', 'pathdef.m')
    % 0 if the file was saved successfully; 1 otherwise
    path_saved = true;
end
warning(orig_warning_state); % Restore the behavior of displaying warnings

% If path not saved, try editing the startup.m of this user
edit_startup_failed = false;
user_startup = fullfile(userpath,'startup.m');
add_path_string = sprintf('addpath(''%s'');', interfaces);
full_add_path_string = sprintf('%s\t%s Added by PDFO', add_path_string, '%');
% First, check whether full_add_path_string already exists in user_startup or not
if exist(user_startup, 'file')
    startup_text_cells = regexp(fileread(user_startup), '\n', 'split');
    if any(strcmp(startup_text_cells, full_add_path_string))
        path_saved = true;
    end
end

if ~path_saved && numel(userpath) > 0
    % Administrators may set userpath to empty for certain users, especially
    % on servers. In that case, userpath = [], and user_startup = 'startup.m'.
    % We will not use user_startup. Otherwise, we will only get a startup.m
    % in the current directory, which will not be executed when MATLAB starts
    % from other directories.

    % We first check whether the last line of the user startup script is an
    % empty line (or the file is empty or even does not exist at all).
    % If yes, we do not need to put a line break before the path adding string.
    if exist(user_startup, 'file')
        startup_text_cells = regexp(fileread(user_startup), '\n', 'split');
        last_line_empty = isempty(startup_text_cells) || (isempty(startup_text_cells{end}) && isempty(startup_text_cells{max(1, end-1)}));
    else
        last_line_empty = true;
    end
    file_id = fopen(user_startup, 'a');
    if file_id ~= -1 % If FOPEN cannot open the file, it returns -1
        if ~last_line_empty  % The last line of user_startup is not empty
            fprintf(file_id, '\n');  % Add a new empty line
        end
        fprintf(file_id, '%s', full_add_path_string);
        fclose(file_id);
        if exist(user_startup, 'file')
            startup_text_cells = regexp(fileread(user_startup), '\n', 'split');
            if any(strcmp(startup_text_cells, full_add_path_string))
                path_saved = true;
            end
        end
    end
    if ~path_saved
        edit_startup_failed = true;
    end
end

if edit_startup_failed
    fprintf('\nFailed to edit your startup script. However, you CAN still use the package without any problem.\n');
else
    fprintf('\nThe package is ready to use.\n');
end

fprintf('\nYou may now try ''help pdfo'' for information on the usage of the package.\n');
addpath(tests);
fprintf('\nYou may also run ''testpdfo'' to test the package on a few examples.\n\n');

if ~path_saved % All the path-saving attempts failed
    fprintf('*** To use the pacakge in other MATLAB sessions, do one of the following. ***\n\n');
    fprintf('- EITHER run ''savepath'' right now if you have the permission to do so.\n\n');
    fprintf('- OR add the following line to your startup script\n');
    fprintf('  (see https://www.mathworks.com/help/matlab/ref/startup.html for information):\n\n');
    fprintf('  %s\n\n', add_path_string);
end

% setup ends
return

%%%%%%%%%%%%%%% Function for file names with handling wildcard %%%%%%%%%%%
function full_files = files_with_wildcard(dir_name, wildcard_string)
%FULL_FILES returns a cell array of files that match the wildcard_string
% under dir_name.
% MATLAB R2015b does not handle commands with wildcards like
% delete(*.o)
% or
% mex(*.f)
% This function enables a workaround.
files = dir(fullfile(dir_name, wildcard_string));
full_files = cellfun(@(s)fullfile(dir_name, s), {files.name}, 'uniformoutput', false);
return

%%%%%%%%%%%%%%%%%% Function for verifying the set-up of MEX %%%%%%%%%%%%%%
function success = mex_well_configured(language)
%MEX_WELL_CONFIGURED verifies the set-up of MEX for compiling language
orig_warning_state = warning;
warning('off','all'); % We do not want to see warnings when verifying MEX

callstack = dbstack;
funname = callstack(1).name; % Name of the current function

ulang = upper(language);

success = 1;
% At return,
% success = 1 means MEX is well configured,
% success = 0 means MEX is not well configured,
% success = -1 means "mex -setup" runs successfully, but either we cannot try
% it on the example file because such a file is not found, or the MEX file of
% the example file does not work as expected.

% Locate example_file, which is an example provided by MATLAB for trying MEX.
% NOTE: MATLAB MAY CHANGE THE LOCATION OF THIS FILE IN THE FUTURE.
switch ulang
case 'FORTRAN'
    example_file = fullfile(matlabroot, 'extern', 'examples', 'refbook', 'timestwo.F');
case {'C', 'C++', 'CPP'}
    example_file = fullfile(matlabroot, 'extern', 'examples', 'refbook', 'timestwo.c');
otherwise
    error(sprintf('%s:UnsupportedLang', funname), '%s: Language ''%s'' is not supported by %s.', funname, language, funname);
end

try
    %[~, mex_setup] = evalc('mex(''-setup'', ulang)'); % Use evalc so that no output will be displayed
    mex_setup = mex('-setup', ulang); % mex -setup may be interactive. So it is not good to mute it completely!!!
    if mex_setup ~= 0
        error(sprintf('%s:MexNotSetup', funname), '%s: MATLAB has not got MEX configured for compiling %s.', funname, language);
    end
catch
    fprintf('\nYour MATLAB failed to run mex(''-setup'', ''%s'').\n', language);
    success = 0;
end

if success == 1 && ~exist(example_file, 'file')
    fprintf('\n')
    wid = sprintf('%s:ExampleFileNotExist', funname);
    warning('on', wid);
    warning(wid, 'We cannot find\n%s,\nwhich is a MATLAB built-in example for trying MEX on %s. It will be ignored.\n', example_file, language);
    success = -1;
end

if success == 1
    try
        [~, mex_status] = evalc('mex(example_file)'); % Use evalc so that no output will be displayed
        if mex_status ~= 0
            error(sprintf('%s:MexFailed', funname), '%s: MATLAB failed to compile %s.', funname, example_file);
        end
    catch
        fprintf('\nThe MEX of your MATLAB failed to compile\n%s,\nwhich is a MATLAB built-in example for trying MEX on %s.\n', example_file, language);
        success = 0;
    end
end

if success == 1
    try
        [~, timestwo_out] = evalc('timestwo(1)'); % Try whether timestwo works correctly
    catch
        fprintf('\nThe MEX of your MATLAB compiled\n%s,\nbut the resultant MEX file does not work.\n', example_file);
        success = 0;
    end
end

if success == 1 && abs(timestwo_out - 2)/2 >= 10*eps
    fprintf('\n')
    wid = sprintf('%s:ExampleFileWorksIncorrectly', funname);
    warning('on', wid);
    warning(wid, 'The MEX of your MATLAB compiled\n%s,\nbut the resultant MEX file returns %.16f when calculating 2 times 1.', example_file, timestwo_out);
    success = -1;
end

cpwd = fileparts(mfilename('fullpath')); % Current directory
trash_files = files_with_wildcard(cpwd, 'timestwo.*');
cellfun(@(filename) delete(filename), trash_files);

warning(orig_warning_state); % Restore the behavior of displaying warnings
return

%%%%%%%%%%%%% Function for removing the compiled MEX files  %%%%%%%%%%%%
function clean_mex
%CLEAN_MEX removes the compiled MEX files.

fprintf('\nRemoving the compiled MEX files (if any) ... ');
% The full path of several directories.
cpwd = fileparts(mfilename('fullpath')); % Current directory
matd = fullfile(cpwd, 'matlab'); % Matlab directory
interfaces = fullfile(matd, 'interfaces'); % Directory of the interfaces
interfaces_private = fullfile(interfaces, 'private'); % The private subdirectory of the interfaces

% Remove the compiled MEX files
mex_files = files_with_wildcard(interfaces_private, '*.mex*');
cellfun(@(filename) delete(filename), mex_files);

fprintf('Done.\n\n');
return

%%%%%%%%%%%%%%%%%%%%% Function for uninstalling pdfo %%%%%%%%%%%%%%%%%%%%
function uninstall_pdfo
%UNINSTALL_PDFO uninstalls PDFO.

fprintf('\nUninstalling PDFO (if it is installed) ... ');

% The full path of several directories.
cpwd = fileparts(mfilename('fullpath')); % Current directory
matd = fullfile(cpwd, 'matlab'); % Matlab directory
interfaces = fullfile(matd, 'interfaces'); % Directory of the interfaces
interfaces_private = fullfile(interfaces, 'private'); % The private subdirectory of the interfaces
tests = fullfile(matd, 'tests'); % Directory containing some tests

% Remove the compiled MEX files
mex_files = files_with_wildcard(interfaces_private, '*.mex*');
cellfun(@(filename) delete(filename), mex_files);

% Try removing the paths possibly added by PDFO
orig_warning_state = warning;
warning('off', 'MATLAB:rmpath:DirNotFound'); % Maybe the paths were not added. We do not want to see this warning.
warning('off', 'MATLAB:SavePath:PathNotSaved'); % Maybe we do not have the permission to save path.
rmpath(interfaces, tests);
savepath;
warning(orig_warning_state); % Restore the behavior of displaying warnings

% Removing the line possibly added to the user startup script
user_startup = fullfile(userpath,'startup.m');
if exist(user_startup, 'file')
    add_path_string = sprintf('addpath(''%s'');', interfaces);
    full_add_path_string = sprintf('%s\t%s Added by PDFO', add_path_string, '%');
    try
        del_str_ln(user_startup, full_add_path_string);
    catch
        % Do nothing.
    end
end

fprintf('Done.\nYou may now remove the current directory if it contains nothing you want to keep.\n\n');
return

%% Function for deleting from a file all the lines containing a string %%
function del_str_ln(filename, string)
%DEL_STR_LN deletes from filename all the lines that are identical to string
fid = fopen(filename, 'r');
if fid == -1
    error('Cannot open file %s.', filename);
end

% Read the file into a cell of strings
data = textscan(fid, '%s', 'delimiter', '\n', 'whitespace', '');
fclose(fid);
cstr = data{1};
% Remove the rows containing string
cstr(strcmp(cstr, string)) = [];

% Save the file again
fid = fopen(filename, 'w');
if fid == -1
    error('Cannot open file %s.', filename);
end
fprintf(fid, '%s\n', cstr{:});
fclose(fid);
return


%% Function for replacing all the string `old_str` with the string `new_str` in a file.
function rep_str(filename, old_str, new_str)
%REP_STR replaces all `old_str` in filename with `new_str`.
fid = fopen(filename, 'r');
if fid == -1
    error('Cannot open file %s.', filename);
end

% Read the file into a cell of strings
data = textscan(fid, '%s', 'delimiter', '\n', 'whitespace', '');
fclose(fid);
cstr = data{1};
% Replace `old_str` with `new_str`.
for i = 1 : length(cstr)
    cstr{i} = strrep(cstr{i}, old_str, new_str);
end

% Save the file again
fid = fopen(filename, 'w');
if fid == -1
    error('Cannot open file %s.', filename);
end
fprintf(fid, '%s\n', cstr{:});
fclose(fid);
return
