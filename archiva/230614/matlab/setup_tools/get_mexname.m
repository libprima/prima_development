function mexname = get_mexname(solver, precision, debug_flag, variant, mexdir)
%GET_MEXNAME returns the name of the mexified `solver` according to `precision`, `debug_flag`,
% `variant`, and `mexdir`.
% N.B.:
% 1. `get_mexname` accepts 4 or 5 arguments:
%    get_mexname(solver, precision, debug_flag, variant),
%    get_mexname(solver, precision, debug_flag, variant, mexdir),
%    where `solver` is a member of `all_solvers()` in the last two cases.
% 2. `get_mexname` can be called during setup or runtime. During setup, `get_mexname` decides the
%    name of the MEX file to compile; during runtime, it decides the name of MEX file to call.
% 3. `get_mexname` has 4 inputs if it is called during setup and 5 inputs if it is called during runtime.
% 4. In general, `mexname` will contain the character returned by `dbgstr(debug_flag)`. However,
%    when variant == classical, `mexname` will contain `dbgstr(false)` regardless of `debug_flag`;
%    during runtime , `mexname` will contain either `dbgstr(debug_flag)` or `dbgstr(false)`,
%    depending on the availability of the corresponding MEX file under `mexdir`.

callstack = dbstack;
funname = callstack(1).name; % Name of the current function

if nargin ~= 4 && nargin ~= 5
    % Private/unexpected error
    error(sprintf('%s:InvalidInput', funname), '%s: UNEXPECTED ERROR: invalid number of inputs.', funname);
elseif ~ischarstr(solver) || ~ismember(solver, all_solvers())
    % Private/unexpected error
    error(sprintf('%s:InvalidInput', funname), '%s: UNEXPECTED ERROR: invalid solver received', funname);
end

if nargin == 5 && (~ischarstr(mexdir) || isempty(mexdir))
    % Private/unexpected error
    error(sprintf('%s:InvalidInput', funname), '%s: UNEXPECTED ERROR: invalid mexdir received', funname);
end

% Check the `precision`, `debug_flag`, and `variant` are valid when there are 4 or 5 inputs.
if nargin == 4  % In this case, we are in setup.
    precision_list = all_precisions_possible();
    variant_list = all_variants_possible();
elseif nargin == 5  % In this case, we are in runtime.
    precision_list = all_precisions();
    variant_list = all_variants();
end

if ~(ischarstr(precision) && ismember(precision, precision_list))
    % Private/unexpected error
    error(sprintf('%s:InvalidInput', funname), '%s: UNEXPECTED ERROR: invalid precision received', funname);
elseif ~islogicalscalar(debug_flag)
    % Private/unexpected error
    error(sprintf('%s:InvalidInput', funname), '%s: UNEXPECTED ERROR: invalid debugging flag received', funname);
elseif ~(ischarstr(variant) && ismember(variant, variant_list))
    % Private/unexpected error
    error(sprintf('%s:InvalidInput', funname), '%s: UNEXPECTED ERROR: invalid variant received', funname);
end

% Start the real business
% Modify `debug_flag` according to `variant`: we do not provide a debugging version for the
% classical variant, for which the support is limited,
debug_flag = debug_flag && ~strcmp(variant, 'classical');
mexname = [solver, '_', precision(1), dbgstr(debug_flag), variant(1)];

% When nargin == 5, this function is called during runtime. If the `mexname` defined above is not
% available under `mexdir`, then we redefine `mexname` by switching debug_flag to false.
if nargin == 5 && ~exist(fullfile(mexdir, mexname), 'file')
    mexname = [solver, '_', precision(1), dbgstr(false), variant(1)];
end

return
