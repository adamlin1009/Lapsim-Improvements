function [Ku, model, diag] = estimate_understeer_gradient(ay, steer, opts)
%ESTIMATE_UNDERSTEER_GRADIENT Robust Ku from skidpad ay/steer arrays.
%   [Ku, model, diag] = ESTIMATE_UNDERSTEER_GRADIENT(ay, steer, opts)
%
%   Inputs:
%     ay, steer : numeric vectors (same length). Units: ay in g, steer in deg.
%     opts      : same tunables as fit_linear_region; optional.
%
%   Outputs:
%     Ku    : understeer gradient (deg/g)
%     model : struct from fit_linear_region (slope/intercept, masks, options)
%     diag  : diagnostics from fit_linear_region (R2, residuals, weights,...)
%
%   Example:
%     [Ku, model] = estimate_understeer_gradient(ay, steer);
%     fprintf('Ku = %.3f deg/g\n', Ku);

    arguments
        ay (:,1) double
        steer (:,1) double
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

    % Ensure basic validity
    assert(numel(ay) == numel(steer), 'ay and steer must match length');
    assert(all(isfinite(ay)) && all(isfinite(steer)), 'ay/steer must be finite');

    % Delegate to robust fitter
    [model, diag] = fit_linear_region(ay(:), steer(:), opts);
    Ku = model.slope; % deg/g
end

