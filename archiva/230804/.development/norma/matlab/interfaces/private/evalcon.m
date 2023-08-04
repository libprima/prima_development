function [cineq, ceq, succ] = evalcon(invoker, nonlcon, x, constrmax)
%EVALCON evaluates a constraint function `[cineq, ceq] = nonlcon(x)`.
% In particular, it uses a 'moderated extreme barrier' to cope with 'hidden constraints' or
% evaluation failures.

succ = true;

try
    [cineq, ceq] = nonlcon(x);
catch exception
    succ = false;
    cineq = NaN;
    ceq = NaN;
    wid = sprintf('%s:ConstraintFailure', invoker);
    if ~isempty(exception.identifier)
        wmsg = sprintf('%s: Constraint function fails with the following error:\n  %s: %s\n  Error occurred in %s, line %d', ...
            invoker, exception.identifier, exception.message, exception.stack(1).file, exception.stack(1).line);
    else
        wmsg = sprintf('%s: Constraint function fails with the following error:\n  %s\n  Error occurred in %s, line %d', ...
            invoker, exception.message, exception.stack(1).file, exception.stack(1).line);
    end
    warning(wid, '%s', wmsg);
end

if ~(isempty(cineq) || isnumeric(cineq))
    succ = false;
    cineq = NaN;
end

if ~(isempty(ceq) || isnumeric(ceq))
    succ = false;
    ceq = NaN;
end

% Use a 'moderated extreme barrier' to cope with 'hidden constraints' or evaluation failures.
if any(isnan(cineq) | ~isreal(cineq) | cineq > constrmax)
    wid = sprintf('%s:ConstraintAbnormalReturn', invoker);
    xstr = sprintf('%g    ', x);
    if any(~isreal(cineq))
        cstr = sprintf('%g%+gi    ', [real(cineq(:)), imag(cineq(:))].');
    else
        cstr = sprintf('%g    ', cineq);
    end
    wmsg = sprintf('%s: Constraint function returns cineq =\n%s\nAny value that is not real or above constrmax = %g is replaced by constrmax.\nThe value of x is:\n%s\n', invoker, cstr, constrmax, xstr);
    warning(wid, '%s', wmsg);
    %warnings = [warnings, wmsg];  % We do not record this warning in the output.

    % Apply the moderated extreme barrier:
    cineq(~isreal(cineq) | cineq~= cineq | cineq > constrmax) = constrmax;
end

if any(isnan(ceq) | ~isreal(ceq) | abs(ceq) > constrmax)
    wid = sprintf('%s:ConstraintAbnormalReturn', invoker);
    xstr = sprintf('%g    ', x);
    if any(~isreal(ceq))
        cstr = sprintf('%g%+gi    ', [real(ceq(:)), imag(ceq(:))].');
    else
        cstr = sprintf('%g    ', ceq);
    end
    wmsg = sprintf('%s: Constraint function returns ceq =\n%s\nAny value that is not real or with an absolute value above constrmax = %g is replaced by constrmax.\nThe value of x is:\n%s\n', invoker, cstr, constrmax, xstr);
    warning(wid, '%s', wmsg);
    %warnings = [warnings, wmsg];  % We do not record this warning in the output.

    % Apply the moderated extreme barrier:
    ceq(~isreal(ceq) | ceq ~= ceq | ceq > constrmax) = constrmax;
    ceq(ceq < -constrmax) = -constrmax;
end

% This part is NOT an extreme barrier. We replace extremely negative values of
% cineq (which leads to no constraint violation) by -constrmax. Otherwise,
% NaN or Inf may occur in the interpolation models.
cineq(cineq < -constrmax) = -constrmax;

cineq = double(real(cineq(:))); % Some functions like 'asin' can return complex values even when it is not intended
ceq = double(real(ceq(:)));
return
