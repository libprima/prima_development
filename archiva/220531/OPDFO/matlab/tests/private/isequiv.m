function isequiv(solvers, options)
%This function verifies that two solvers produce the same result on CUTEst problems.
%
% As an example:
% options=[]; options.maxdi=20; options.nr=20; isequiv({'newuoa', 'newuoa'}, options)
%
% verifies newuoa against newuoa on problems of at most 20 variables, 20 random runs for each problem.
%
% Coded by Zaikun ZHANG (www.zhangzk.net).
%
% Started: July 2020
%
% Last Modified: Monday, October 04, 2021 PM09:19:19
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


if nargin < 1
    fprintf('\nSolvers must be specified.\n');
    return
end

if length(solvers) ~= 2
    fprintf('\nThere should be two solvers.\n')
    return
end

if nargin == 1
    options = struct();
end

if isfield(options, 'prec')
    prec = options.prec;
else
    prec = 0;
end
if isfield(options, 'nr')
    nr = options.nr;
else
    nr = 10;
end
if isfield(options, 'ir')
    % ir is the index of the random experiment to be conducted. If it is negative, then experiments
    % 1, ..., nr, ..., nr + 20 will be conducted. nr + 20 is because there are fixed experiments
    % that will always be run.
    ir = options.ir;
else
    ir = -1;
end

if isfield(options, 'minip')
    minip=options.minip;
else
    minip = 1;
end

requirements = struct();
if isfield(options, 'list')
    requirements.list = options.list;  % Only test problems in this list
else
    requirements.list = {};  % No restriction
end
if (isfield(options, 'mindim'))
    requirements.mindim = options.mindim;
else
    requirements.mindim = 1;
end
if (isfield(options, 'maxdim'))
    requirements.maxdim = options.maxdim;
else
    if strcmpi(solvers{1}, 'cobyla') || strcmpi(solvers{2}, 'cobyla')
        requirements.maxdim = 20;
    else
        requirements.maxdim = 50;
    end
end
if (isfield(options, 'mincon'))
    requirements.mincon = options.mincon;
else
    requirements.mincon = 0;
end
if (isfield(options, 'maxcon'))
    requirements.maxcon = options.maxcon;
else
    requirements.maxcon = min(5000, 100*requirements.maxdim);
end
if (isfield(options, 'type'))
    requirements.type = options.type;
else
    requirements.type = 'ubln';
end

if ir < 0
    minir = 0;
    maxir = nr + 20;
else
    minir = ir;
    maxir = ir;
end

if ~isempty(requirements.list)
    plist = requirements.list; % Use the list provided by the user
    if (ischstr(plist))  % In case plist is indeed the name of a problem
        plist = {plist};
    end
else
    blacklist = {};
    %blacklist={'gauss2', 'gauss3','HS25NE', 'cubene'};  % Memory error
    switch lower(solvers{1})
    case {'uobyqa', 'uobyqa'}
        blacklist = [blacklist, {'VARDIM', 'HATFLDFL'}];  % too large for UOBYQA
    case {'newuoa', 'newuoa'}
        blacklist = [blacklist, {'ARGTRIGLS', 'BROWNAL', 'VARDIM'}]; % More than 30 minutes to solve.
        %blacklist = [blacklist, {'PENALTY2'}]; % More than 5 minutes to solve.
    case {'bobyqa', 'bobyqa'}
        blacklist = [blacklist, {'STREG'}]; % bobyqa returns an fx that does not match x; should test it after the modernization.
        blacklist = [blacklist, {'ARGTRIGLS', 'BROWNAL', 'VARDIM'}];  % More than 10 minutes to solve.
    case {'lincoa', 'lincoa'}
        blacklist = [blacklist, {'LSNNODOC', 'HS55'}]; % possible reason for a segfault; should test it after the modernization.
        blacklist = [blacklist, {'AVGASA', 'AVGASB'}];  % SEGFAULT on 20220306
        blacklist = [blacklist, {'CHEBYQAD'}]; % The classical lincoa encounters segfault
        blacklist = [blacklist, {'ARGTRIGLS', 'BROWNAL', 'PENALTY3', 'VARDIM'}]; % More than 10 minutes to solve.
        blacklist = [blacklist, {' QPNBOEI2', 'QPCBOEI2'}]; % Too long to solve
    case {'cobyla', 'cobyla'}
        blacklist = [blacklist, {'MINMAXRB'}]; % Classical COBYLA encounters SEGFAULT
        if requirements.maxdim <= 50  % This means we intend to have a quick test with small problems
            blacklist=[blacklist, {'BLEACHNG'}];  % A 17 dimensional bound-constrained problem that
                                                  % takes too much time for a small problem
        end
        blacklist = [blacklist, {'PRODPL0', 'DEGENLPB'}]; % Takes long to solve
        blacklist=[blacklist, {'DMN15102', 'DMN15103', 'DMN15332', 'DMN15333', 'DMN37142', 'DMN37143'}]; % Takes more than 5 min to solve
        blacklist = [blacklist, {'KISSING2', 'LUKSAN16', 'QPCBLEND', 'VANDERM4'}]; % Takes more than 20 sec to solve
        %blacklist = [blacklist, {'DUAL2', 'FEEDLOC', 'GROUPING', 'HYDCAR20', 'LINSPANH', 'LUKSAN11', ...
        %    'LUKSAN12', 'LUKSAN13', 'LUKSAN14', 'LUKSAN15', 'LUKSAN17', 'LUKSAN21', 'LUKSAN22', ...
        %    'MANCINONE', 'QPNBLEND', 'SPANHYD', 'SWOPF', 'TAX13322', 'TAXR13322', 'TRO4X4', ...
        %    'VANDERM1', 'VANDERM2', 'VANDERM3'}];  % Takes more than 10 sec to solve

        % 51-100 dimensional problems that take too long time to be used in the verification.
        blacklist = [blacklist, {'HYDCAR20', 'LUKSAN13', 'CHEBYQADNE', 'HAIFAM', 'LUKSAN12', 'HIMMELBI', 'DUAL1', ...
            'AIRPORT', 'CHEBYQAD', 'LUKSAN14LS', 'LUKSAN13LS', 'HYDC20LS', 'LUKSAN11LS', 'LUKSAN12LS', 'CORE1', ...
            'LUKSAN14', 'DUAL2', 'LUKSAN15', 'ACOPP30', ...  % 6~10 min
            'VANDERM3', 'CHANDHEQ', ... % > 5 min
            'DECONVB', 'ACOPR30', ... % > 4 min
            'DECONVC', 'LAKES', 'KISSING2', ... % > 3 min
            'LUKSAN11', 'FEEDLOC', 'VANDERM2', 'MSS1', 'VANDERM1', 'GROUPING', 'LINSPANH', ...  % > 2 min
            'DECONVU', 'DUAL4'}];  % > 1 min

        % blacklist when QRADD/QREXC calls ISORTH
        blacklist = [blacklist, {'ACOPP30', 'ACOPR30', 'AIRPORT', 'BATCH', 'CHANDHEQ', 'CHEBYQAD', 'CHEBYQADNE', 'CHNRSBNE', ...
        'CHNRSNBMNE', 'CORE1', 'CRESC132', 'DALLASS', 'DECONVB', 'DECONVBNE', 'DECONVU', 'DEGENQPC', 'DUAL1', 'DUAL2', ...
        'ERRINRSM','ERRINRSMNE', 'FBRAIN3', 'FEEDLOC', 'GROUPING', 'HAIFAM', 'HIMMELBI', 'HYDC20LS', 'HYDCAR20', 'KISSING2', ...
        'LAKES', 'LUKSAN11', 'LUKSAN11LS', 'LUKSAN12', 'LUKSAN12LS', 'LUKSAN13', 'LUKSAN13LS', 'LUKSAN14', 'LUKSAN14LS', ...
        'LUKSAN15', 'LUKSAN16', 'LUKSAN17', 'LUKSAN17LS', 'LUKSAN21', 'LUKSAN21LS', 'LUKSAN22', 'LUKSAN22LS', ...
        'MANCINONE', 'MSS1', 'NET1', 'SPANHYD', 'SWOPF', 'TAX13322', 'TAXR13322', 'TRO4X4', 'TRO6X2', 'VANDERM1', ...
        'VANDERM2', 'VANDERM3', 'VESUVIOU'}];  % 20211125 version of COBYLAN takes more than 2 minutes to solve

        % blacklist when QRADD/QREXC do not call ISORTH
        %blacklist = [blacklist, {'AIRPORT', 'BATCH', 'CHEBYQAD', 'CHEBYQADNE', 'CHNRSBNE', 'CHNRSNBMNE', ...
        %'CORE1', 'CRESC132', 'DALLASS', 'DECONVB', 'DECONVBNE', 'DEGENQPC', 'DUAL1', 'DUAL2', 'ERRINRSM', ...
        %'ERRINRSMNE', 'FBRAIN3', 'HAIFAM', 'HIMMELBI', 'HYDC20LS', 'HYDCAR20', ...
        %'LAKES', 'LUKSAN11LS', 'LUKSAN12', 'LUKSAN12LS', 'LUKSAN13', 'LUKSAN13LS', 'LUKSAN14', 'LUKSAN14LS', ...
        %'LUKSAN15', 'LUKSAN16', 'LUKSAN17', 'LUKSAN17LS', 'LUKSAN21', 'LUKSAN21LS', 'LUKSAN22', 'LUKSAN22LS', ...
        %'MSS1', 'NET1', 'SPANHYD', 'SWOPF', 'TAX13322', 'TAXR13322', 'TRO4X4', 'TRO6X2', 'VANDERM1', ...
        %'VANDERM2', 'VANDERM3', 'VESUVIOU'}];  % 20211125 version of COBYLAN takes more than 2 minutes to solve
    end
    requirements.blacklist = blacklist;
    plist = secup(requirements);
end

single_test = (length(plist) <= 1);
if isfield(options, 'sequential')
    sequential = options.sequential;
else
    sequential = single_test;
end

if sequential
    for ip = minip : length(plist)
        orig_warning_state = warnoff(solvers);
        pname = upper(plist{ip});

        fprintf('\n%3d. \t%s:\n', ip, pname);

        prob = macup(pname);

        for ir = minir : maxir
            fprintf('\n%s Run No. %3d:\n', pname, ir);
            % The following line compares the solvers on `prob`; ir is needed for the random seed, and
            % `prec` is the precision of the comparison (should be 0). The function will raise an error
            % if the solvers behave differently.
            compare(solvers, prob, ir, prec, single_test, options);
        end

        decup(pname);
        warning(orig_warning_state); % Restore the behavior of displaying warnings
    end
else
    parfor ip = minip : length(plist)

        orig_warning_state = warnoff(solvers);

        pname = upper(plist{ip});

        fprintf('\n%3d. \t%s:\n', ip, pname);

        prob = macup(pname);

        for ir = minir : maxir
            %fprintf('\n%s Run No. %3d:\n', pname, ir);
            % The following line compares the solvers on `prob`; ir is needed for the random seed, and
            % `prec` is the precision of the comparison (should be 0). The function will raise an error
            % if the solvers behave differently.
            compare(solvers, prob, ir, prec, single_test, options);
        end

        decup(pname);
        warning(orig_warning_state); % Restore the behavior of displaying warnings
    end
end

fprintf('\n\nSucceed!\n\n');   % Declare success if we arrive here without an error.

return


function eq = iseq(x, f, exitflag, output, xx, ff, ee, oo, prec)
eq = true;

if ~isempty(setdiff(fieldnames(output), [fieldnames(oo); 'fhist'; 'xhist'; 'chist'; 'nlcihist'; 'nlcehist'])) ...
        || ~isempty(setdiff(fieldnames(oo), [fieldnames(output); 'fhist'; 'xhist'; 'chist'; 'nlcihist', 'nlcehist']))
    eq = false;
end

if ~isfield(output,'constrviolation')
    output.constrviolation = 0;
end
if ~isfield(oo,'constrviolation')
    oo.constrviolation = 0;
end

if ~isfield(output, 'chist')
    output.chist = zeros(output.funcCount, 1);
end
if ~isfield(oo, 'chist')
    oo.chist = zeros(oo.funcCount, 1);
end

if (norm(xx-x)/(1+norm(x)) > prec || abs(ff-f)/(1+abs(f)) > prec ...
        || abs(oo.constrviolation-output.constrviolation)/(1+abs(output.constrviolation)) > prec)
    eq = false;
end

if isfield(output, 'fhist')
    output.fhist = output.fhist(:);
else
    output.fhist = [];
end
if isfield(oo, 'fhist')
    oo.fhist = oo.fhist(:);
else
    oo.fhist = [];
end
nhist = min(length(output.fhist), length(oo.fhist));
output.fhist = output.fhist(end - nhist + 1: end);
oo.fhist = oo.fhist(end - nhist + 1: end);

minfhist = min(length(output.fhist), length(oo.fhist));
if norm(output.fhist(end-minfhist+1:end) - oo.fhist(end-minfhist+1:end))/(1+norm(output.fhist(end-minfhist+1:end))) > prec
    eq = false;
end

minchist = min(length(output.chist), length(oo.chist));
if norm(output.chist(end-minchist+1:end) - oo.chist(end-minchist+1:end))/(1+norm(output.chist(end-minchist+1:end))) > prec
    eq = false;
end

if (prec == 0 && (exitflag ~= ee|| oo.funcCount ~= output.funcCount))
    eq = false;
end

%diff = max([abs(ff-f)/(1+abs(f)), norm(xx-x)/(1+norm(x)), ...
%    abs(oo.constrviolation-output.constrviolation)/(1+abs(output.constrviolation))]);

return



function f = noisy(f, x, noise_level)
if nargin < 3
    noise_level = 2e-1;
end
r = cos(1.0D6 * sin(1.0D6 * (abs(f) + 1.0D0) * cos(1.0D6 * sum(abs(x)))));
f = f*(1+noise_level*r);
if (r > 0.75)
    f = inf;
elseif (r > 0.5)
    f = NaN;
elseif (r < - 0.999)
    f = -1e30;
end
return



function f = noisyfeval(func, x, noise_level)
if nargin < 3
    noise_level = 2e-1;
end
f = func(x);
f = noisy(f, x, noise_level);
return



function [cineq, ceq] = noisyceval(con, x, noise_level)
if nargin < 3
    noise_level = 2e-1;
end
[cineq, ceq] = con(x);
for i = 1 : length(cineq)
    cineq(i) = noisy(cineq(i), x, noise_level);
end
for i = 1 : length(ceq)
    ceq(i) = noisy(ceq(i), x, noise_level);
end
return



function equiv = compare(solvers, prob, ir, prec, single_test, options)
pname = prob.name;
objective = prob.objective;
nonlcon = prob.nonlcon;
x0 = prob.x0;
n = length(x0);

% Some randomization
% Set seed using pname, n, and ir. We ALTER THE SEED weekly to test the solvers as much as possible.
% N.B.: The weeknum function considers the week containing January 1 to be the first week of the
% year, and increments the number every SUNDAY.
if isfield(options, 'yw')
    yw = options.yw;
elseif isfield(options, 'seed')
    yw = options.seed;
else
    tz = 'Asia/Shanghai';  % Specify the timezone for reproducibility.
    dt = datetime('now', 'TimeZone', tz);
    yw = 100*mod(year(dt), 100) + week(dt);
end
fprintf('\nYW = %d\n', yw);
rseed = max(0, min(2^32, yw+ceil(1e5*abs(cos(1e5*sin(1e5*(sum(double(pname))*n*ir)))))));
rng(rseed);
prob.x0 = x0 + 0.5*randn(size(x0));
test_options = struct();
test_options.rhobeg = 1 + 0.5*(2*rand-1);
test_options.rhoend = 1e-3*(1 + 0.5*(2*rand-1));
test_options.npt = max(min(floor(6*rand*n), (n+2)*(n+1)/2), n+2);
if isfield(options, 'maxfun')
    test_options.maxfun = options.maxfun;
else
    test_options.maxfun = max(ceil(20*n*(1+rand)), n+3);
end
test_options.ftarget = objective(x0) - 10*abs(randn)*max(1, objective(x0));
test_options.fortran = (rand > 0.5);
test_options.output_xhist = (rand > 0.5);
test_options.output_nlchist = (rand > 0.5);
test_options.maxhist = ceil(randn*1.5*test_options.maxfun);
if single_test
    % DO NOT INVOKE ANY RANDOMIZATION WITHIN THIS IF. Otherwise, a single test cannot reproduce the
    % corresponding test in a multiple one.
    test_options.maxhist = test_options.maxfun;
    test_options.output_xhist = true;
    test_options.output_nlchist = true;
end
test_options.maxfilt = ceil(randn*500);
test_options.iprint = floor(3*rand);
test_options.quiet = (rand < 0.9);
% Test all precisions. For unavailable precisions, the double-precision version will be called.
if rand < 0.6  % Prob = 0.6
    test_options.precision = 'double';
elseif rand < 0.8  % Prob = 0.32
    test_options.precision = 'single';
else  % Prob = 0.08
    test_options.precision = 'quadruple';
end

%!------------------------------------------------------------------------------------------------!%
% Test both debugging and non-debugging versions. They may behave differently.
% On 20220302, it is observed that, when the Fortran code is compiled with the '-g' (debugging)
% option, the INTENT(OUT) arguments will keep the values that they get before entering subroutines,
% even though such values should be cleared on entry of the subroutines. This behavior makes it
% impossible to detect the arguments that should be INTENT(INOUT) but mistakenly declared as
% INTENT(OUT). The observation was made on the argument named SNORM in the subroutine TRSTEP of
% LINCOA, and it took a whole day to debug.
test_options.debug = (rand < 0.7);
test_options.chkfunval = test_options.debug;
%!------------------------------------------------------------------------------------------------!%

% Test all variants. If the classical variant is unavailable,  the modernized variant will be called.
test_options.classical = (rand < 0.1);
% Test only double for the classical variant; debugging version is unavailable for the classical variant.
if test_options.classical
    test_options.precision = 'double';
    test_options.debug = false;
    test_options.chkfunval = false;
end

call_by_package = (rand < 0.5);  % Call by the package instead of the solver
call_by_structure = (rand < 0.5);  % Pass the problem by a structure
if mod(ir, 50) == 0 && ~isempty(dir('*_output.txt'))
    delete('*_output.txt');
end
if ir == 1
    test_options.npt = (n+2)*(n+1)/2;
end
if ir == 2
    test_options.npt = n + 2;
end
if ir == 3
    test_options.maxfun = test_options.npt + 1;
end
if ir == 4
    test_options.maxfun = 1000*n;
end
if ir == 5
    test_options.maxfun = 1;
end
if ir == 6
    test_options.maxfun = ceil(n/2);
end
if ir == 7
    test_options.ftarget = inf;
end
if ir == 8
    test_options.rhoend = test_options.rhobeg;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ir == 9
    test_options.npt = 2*n;
end
if 10 <= ir && ir <= 12
    test_options.npt = ceil(rand*n^2);
end
if 13 <= ir && ir <= 15
    test_options.npt = floor(2*rand*n);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if 1 <= ir && ir <= 20
    test_options.chkfunval = false;  % The checking would fail due to noise.
    prob.objective = @(x) noisyfeval(objective, x);
    if ~isempty(nonlcon)
        prob.nonlcon = @(x) noisyceval(nonlcon, x);
    end
else
    prob.objective  = objective;
    prob.nonlcon = nonlcon;
end
prob.options = test_options;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Call the solvers %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% N.B.: In some tests, we may invoke this function with solvers{1} == solvers{2}. So do NOT assume
% that one of the solvers is 'SOLVER' and the other is 'SOLVERn'.

solver1 = str2func(solvers{1});  % Use function handle to avoid `feval`.
solver2 = str2func(solvers{2});  % Use function handle to avoid `feval`.

if endsWith(solvers{1}, 'n')
    package1 = @pdfo;
else
    package1 = @pdfo;
end
if endsWith(solvers{2}, 'n')
    package2 = @pdfo;
else
    package2 = @pdfo;
end

tested_solver_name = regexprep(solvers{1}, 'n$', '');

if call_by_package
    if call_by_structure
        prob.options.solver = solvers{1};
        %tic;
        [x1, fx1, exitflag1, output1] = package1(prob);
        %T = toc; fprintf('\nRunning time for %s:\t %f\n', solvers{1}, T);
        prob.options.solver = solvers{2};
        %tic;
        [x2, fx2, exitflag2, output2] = package2(prob);
        %T = toc; fprintf('\nRunning time for %s:\t %f\n', solvers{2}, T);
    else
        prob.options.solver = solvers{1};
        [x1, fx1, exitflag1, output1] = package1(prob.objective, prob.x0, prob.Aineq, ...
            prob.bineq, prob.Aeq, prob.beq, prob.lb, prob.ub, prob.nonlcon, prob.options);
        prob.options.solver = solvers{2};
        [x2, fx2, exitflag2, output2] = package2(prob.objective, prob.x0, prob.Aineq, ...
            prob.bineq, prob.Aeq, prob.beq, prob.lb, prob.ub, prob.nonlcon, prob.options);
    end
else
    if call_by_structure
        [x1, fx1, exitflag1, output1] = solver1(prob);
        [x2, fx2, exitflag2, output2] = solver2(prob);
    else
        switch lower(tested_solver_name)
        case {'uobyqa', 'newuoa'}
            [x1, fx1, exitflag1, output1] = solver1(prob.objective, prob.x0, prob.options);
            [x2, fx2, exitflag2, output2] = solver2(prob.objective, prob.x0, prob.options);
        case {'bobyqa'}
            [x1, fx1, exitflag1, output1] = solver1(prob.objective, prob.x0, prob.lb, prob.ub, prob.options);
            [x2, fx2, exitflag2, output2] = solver2(prob.objective, prob.x0, prob.lb, prob.ub, prob.options);
        case {'lincoa'}
            [x1, fx1, exitflag1, output1] = solver1(prob.objective, prob.x0, ...
                prob.Aineq, prob.bineq, prob.Aeq, prob.beq, prob.lb, prob.ub, prob.options);
            [x2, fx2, exitflag2, output2] = solver2(prob.objective, prob.x0, ...
                prob.Aineq, prob.bineq, prob.Aeq, prob.beq, prob.lb, prob.ub, prob.options);
        case {'cobyla'}
            [x1, fx1, exitflag1, output1] = solver1(prob.objective, prob.x0, ...
                prob.Aineq, prob.bineq, prob.Aeq, prob.beq, prob.lb, prob.ub, prob.nonlcon, prob.options);
            [x2, fx2, exitflag2, output2] = solver2(prob.objective, prob.x0, ...
                prob.Aineq, prob.bineq, prob.Aeq, prob.beq, prob.lb, prob.ub, prob.nonlcon, prob.options);
        otherwise
            error('Wrong solver tested: %s', tested_solver_name);
        end
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Call the solvers %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


if output1.funcCount == test_options.maxfun && (exitflag1 == 0 || exitflag1 == 2) && exitflag2 == 3
    exitflag1 = 3;
    %display('exitflag1 changed to 3.')
end
if output2.funcCount == test_options.maxfun && (exitflag2 == 0 || exitflag2 == 2) && exitflag1 == 3
    exitflag2 = 3;
    %display('exitflag2 changed to 3.')
end
if fx1 <= test_options.ftarget
    exitflag1 = 1;
    %fprintf('exitflag1 changed to 1.\n')
end
if fx2 <= test_options.ftarget
    exitflag2 = 1;
    %fprintf('exitflag2 changed to 1.\n')
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Special Treatments%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
minfhist = min(length(output1.fhist), length(output2.fhist));
% NEWUOA
if strcmpi(solvers{1}, 'newuoa') && strcmpi(solvers{2}, 'newuoa') && exitflag1 == 2 && exitflag2 ~=2 ...
        && fx2 <= fx1 && output1.funcCount <= output2.funcCount ...
        && all(output2.fhist(end-minfhist+1:end-(output2.funcCount-output1.funcCount)) ...
        == output1.fhist(end-minfhist+(output2.funcCount-output1.funcCount)+1:end))
    x2 = x1;
    fx2 = fx1;
    exitflag2 = exitflag1;
    output2.fhist = output1.fhist;
    output2.funcCount = output1.funcCount;
    fprintf('The original solver exits due to failure of the TR subproblem solver.\n');
end
if strcmpi(solvers{1}, 'newuoa') && strcmpi(solvers{2}, 'newuoa') && exitflag2 == 2 && exitflag1 ~=2 ...
        && fx1 <= fx2 && output2.funcCount <= output1.funcCount ...
        && all(output1.fhist(end-minfhist+1:end-(output1.funcCount-output2.funcCount)) ...
        == output2.fhist(end-minfhist+(output1.funcCount-output2.funcCount)+1:end))
    x1 = x2;
    fx1 = fx2;
    exitflag1 = exitflag2;
    output1.fhist = output2.fhist;
    output1.funcCount = output2.funcCount;
    fprintf('The original solver exits due to failure of the TR subproblem solver.\n');
end
if ismember('newuoa', solvers) && fx1 == fx2 && norm(x1 - x2) > 0 && output1.funcCount == output2.funcCount ...
        && all(output1.fhist(end-minfhist+1:end) == output2.fhist(end-minfhist+1:end))
    x1 = x2;
    fprintf('x1 changed to x2\n');
end

% COBYLA
if (ismember('cobyla', solvers) && fx1 == fx2 && norm(x1-x2)>0) ...
        && (~isfield(output1,'constrviolation') && ~isfield(output2, 'constrviolation') ...
        || isfield(output1, 'constrviolation') && output1.constrviolation == output2.constrviolation)
    x1 = x2;
    fprintf('x1 changed to x2.\n');
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

equiv = iseq(x1, fx1, exitflag1, output1, x2, fx2, exitflag2, output2, prec);

if ~equiv
    format long;
    fprintf('\nnf: nf1 = %d, nf2 = %d', output1.funcCount, output2.funcCount)
    fprintf('\nx:')
    x1'
    x2'
    fprintf('\nf: fx1 = %.16e, fx2 = %.16e', fx1, fx2)
    fprintf('\nexitflag: exitflag1 = %d, exitflag2 = %d', exitflag1, exitflag2)
    nhist = min(length(output1.fhist), length(output2.fhist));
    fprintf('\nfhist (compare only the last %d evaluations):', nhist);
    output1.fhist
    output2.fhist
    fhist2 = output1.fhist(end-nhist+1: end);
    fhist1 = output2.fhist(end-nhist+1: end);
    fhist1 == fhist2
    if (isfield(output1, 'constrviolation'))
        fprintf('\nconstrviolation: constrviolation1 = %.16e, constrviolation2 = %.16e', ...
            output1.constrviolation, output2.constrviolation)
        fprintf('\nchist (compare only the last %d evaluations):', nhist);
        output1.chist
        output2.chist
        chist1 = output1.chist(end-nhist+1:end);
        chist2 = output2.chist(end-nhist+1:end);
        chist1 == chist2
    end
    if single_test && options.sequential
        fprintf('\nThe solvers produce different results on %s at the %dth run.\n\n', pname, ir);
        cd(options.olddir);
        keyboard
    end
    error('\nThe solvers produce different results on %s at the %dth run.\n', pname, ir);
end

return



%function [x,fx, exitflag, output] = newuoa1(varargin)
%[x,fx, exitflag, output] = newuoa(varargin, 1);
%return
