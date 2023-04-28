function profile(varargin)
%This function profiles the modernized version of Powell's solver against Powell's version.
%
% Usage:
%
%   profile(solver, dimrange, nocompile_flag, problem_type, options)
%   profile(solver, dimrange, reload_flag, problem_type, options)
%
% where
% - `solver` is the name of the solver to test
% - `dimrange` is the vector [mindim, maxdim], or "small", or "big", or "large"
% - `nocompile_flag` is either 'nocompile' or 'ncp', indicating not to compile the solves
% - `reload_flag` is either 'reload' or 'load', indicating to load the data directly from the .mat
% file corresponding to `solver` and `dimrange`
% - `problem_type` can be any of {'u', 'b', 'l', 'n', 'ub', 'ubl', 'ubln', 'bl', 'bln', 'ln'},
%   indicating the problem type to test
%
% Coded by Zaikun ZHANG (www.zhangzk.net).
%
% Started: October 2021
%
% Last Modified: Monday, October 04, 2021 PM09:19:19
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

olddir = cd();  % Record the current path.
oldpath = path();  % Record the current dir.
restoredefaultpath; % Restore the "right out of the box" path of MATLAB

try

    % Parse the inputs.
    [solver, options] = parse_input(varargin);

    % Mexify the solvers.
    if options.compile
        mex_solvers(solver);
    else
        % Tell MATLAB where to find the solvers.
        locate_solvers();
    end

    % Tell MATLAB where to find CUTEST.
    locate_cutest();

    % Set up the directory to save the testing data.
    testdir = fileparts(mfilename('fullpath')); % Directory where this .m file resides.
    datadir = fullfile(testdir, 'testdata');
    if ~exist(datadir, 'dir')
        mkdir(datadir);
    end
    options.datadir = datadir;

    % Show current path information.
    showpath();

    % Profile the solvers.
    solvers = {[solver, 'n'], solver};
    tic;
    perfdata(solvers, options);
    toc;

catch exception

    setpath(oldpath);  % Restore the path to oldpath.
    cd(olddir);  % Go back to olddir.
    rethrow(exception);

end

setpath(oldpath);  % Restore the path to oldpath.
cd(olddir);  % Go back to olddir.


%%%%%%%%%%%%%%%%%%%%%%%% Auxiliary functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function spaths = locate_solvers()

curdir = cd();

solver_dir = fullfile(fileparts(fileparts(curdir)), 'PDFO', 'matlab', 'interfaces');
addpath(solver_dir);

solvern_dir = fullfile(fileparts(curdir), 'interfaces');
addpath(solvern_dir);

spaths={solver_dir, solvern_dir};
