function [Ku, model, diag] = compute_understeer_gradient(car, opts)
%COMPUTE_UNDERSTEER_GRADIENT Estimate understeer gradient from skidpad data.
%   [Ku, model, diag] = COMPUTE_UNDERSTEER_GRADIENT(car, opts)
%
%   Expects car.comp.skidpad.ay (g) and car.comp.skidpad.steer (deg).
%   Uses fit_linear_region to robustly identify the linear region and fit
%   a line steer = a + Ku * ay. Returns Ku in deg/g.
%
%   opts are passed through to fit_linear_region (see its help).

    arguments
        car
        opts.minPtsFrac (1,1) double {mustBePositive} = 0.25
        opts.minPtsAbs  (1,1) double {mustBeNonnegative} = 10
        opts.winFrac    (1,1) double {mustBePositive} = 0.20
        opts.winMin     (1,1) double {mustBeNonnegative} = 6
        opts.winMax     (1,1) double {mustBeNonnegative} = 10
        opts.slopeTolAbs (1,1) double {mustBeNonnegative} = 0.03
        opts.slopeTolRel (1,1) double {mustBeNonnegative} = 0.20
        opts.resK        (1,1) double {mustBePositive} = 3.0
        opts.resMinAbs   (1,1) double {mustBeNonnegative} = 0.15
        opts.robustMethod (1,1) string {mustBeMember(opts.robustMethod,["huber","bisquare"])} = "huber"
        opts.robustC     (1,1) double {mustBePositive} = 1.345
        opts.maxIter     (1,1) double {mustBePositive} = 25
        opts.tol         (1,1) double {mustBePositive} = 1e-10
    end

    % Fetch skidpad data (supports struct or object with properties)
    [ay, steer] = fetch_skidpad(car);
    ay = ay(:);
    steer = steer(:);

    [model, diag] = fit_linear_region(ay, steer, opts);
    Ku = model.slope; % deg/g
end

function [ay, steer] = fetch_skidpad(car)
%FETCH_SKIDPAD Get skidpad ay/steer arrays from car struct/object.
    if isstruct(car)
        assert(isfield(car,'comp') && isfield(car.comp,'skidpad'), 'car.comp.skidpad required');
        sp = car.comp.skidpad;
        assert(isfield(sp,'ay') && isfield(sp,'steer'), 'skidpad.ay and skidpad.steer required');
        ay = sp.ay; steer = sp.steer;
    elseif isobject(car)
        assert(isprop(car,'comp'), 'car.comp required');
        sp = car.comp.skidpad;
        assert(isprop(sp,'ay') && isprop(sp,'steer'), 'skidpad.ay and skidpad.steer required');
        ay = sp.ay; steer = sp.steer;
    else
        error('Unsupported car type: expected struct or object');
    end
    validateattributes(ay, {'numeric'},{'vector','real','finite'});
    validateattributes(steer, {'numeric'},{'vector','real','finite'});
end

