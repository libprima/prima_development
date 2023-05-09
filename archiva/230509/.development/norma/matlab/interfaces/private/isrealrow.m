function [isrr, len] = isrealrow(x) % isrealrow([]) = true
%ISREALROW checks whether x is a real row. If yes, it returns len = length(x); otherwise, len = NaN.
% N.B.: isrealrow([]) = true.

if isempty(x)
    isrr = true;
    len = 0;
elseif isnumeric(x) && isreal(x) && isvector(x) && size(x, 1) == 1
    isrr = true;
    len = length(x);
else
    isrr = false;
    len = NaN;
end
return
