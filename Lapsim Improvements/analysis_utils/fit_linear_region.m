function [fit, diag] = fit_linear_region(x, y, opts)
%FIT_LINEAR_REGION Robustly find linear region and fit y ~ a + b x
%   [FIT, DIAG] = FIT_LINEAR_REGION(x, y, opts)
%
%   - Sorts data by x, grows a candidate linear region from low-x, and
%     stops when BOTH residuals exceed a robust threshold and the local
%     slope drifts beyond a tolerance from the seed slope.
%   - Uses IRLS robust regression (Huber by default) to estimate slopes.
%
%   Inputs:
%     x, y   : vectors of equal length
%     opts   : struct with optional fields:
%        .minPtsFrac      (default 0.25)   % seed length fraction
%        .minPtsAbs       (default 10)     % minimum absolute seed length
%        .winFrac         (default 0.20)   % sliding window fraction
%        .winMin          (default 6)
%        .winMax          (default 10)
%        .slopeTolAbs     (default 0.03)   % deg/g or general slope units
%        .slopeTolRel     (default 0.20)   % relative to seed slope
%        .resK            (default 3.0)    % residual threshold multiplier
%        .resMinAbs       (default 0.15)   % absolute residual gate
%        .robustMethod    (default 'huber')% 'huber' or 'bisquare'
%        .robustC         (default 1.345)
%        .maxIter         (default 25)
%        .tol             (default 1e-10)
%
%   Outputs:
%     fit.slope, fit.intercept
%     fit.idx_linear (logical mask), fit.cutoff_idx
%     fit.slope_ref (seed slope), fit.options (resolved opts)
%     diag.residuals (final), diag.weights (final), diag.sigma
%     diag.R2, diag.SSE, diag.SST
%
%   This utility is toolbox-free.

    arguments
        x (:,1) double
        y (:,1) double
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

    % ensure column vectors
    x = x(:); y = y(:);
    assert(numel(x)==numel(y), 'x and y must be same length');
    n = numel(x);
    assert(n >= 8, 'At least 8 points are recommended');

    % sort by x
    [x, k] = sort(x);
    y = y(k);

    % window and seed sizes
    minPts = max(opts.minPtsAbs, ceil(opts.minPtsFrac*n));
    W = max(opts.winMin, min(opts.winMax, floor(opts.winFrac*n)));
    minPts = min(max(3, minPts), n);
    W = max(3, min(W, max(3, n - minPts)));

    % seed robust fit
    [b0, w0, r0, s0] = robust_line(x(1:minPts), y(1:minPts), opts.robustMethod, opts.robustC, opts.maxIter, opts.tol);
    slope_ref = b0(2);
    max_error = max(opts.resMinAbs, opts.resK * s0);
    slope_tol = max(opts.slopeTolAbs, opts.slopeTolRel * abs(slope_ref));

    % grow region until BOTH gates fail
    cutoff = n;
    for j = (minPts+W):n
        [bp, ~, rp, ~] = robust_line(x(1:j), y(1:j), opts.robustMethod, opts.robustC, opts.maxIter, opts.tol);
        % trailing window slope
        [bw, ~, ~, ~] = robust_line(x(j-W+1:j), y(j-W+1:j), opts.robustMethod, opts.robustC, opts.maxIter, opts.tol);

        slope_dev = abs(bw(2) - slope_ref);
        res_gate  = max(abs(rp));
        if res_gate > max_error && slope_dev > slope_tol
            cutoff = max(minPts, j - W);
            break
        end
    end

    idx_linear = false(n,1); idx_linear(1:cutoff) = true;
    [bf, wf, rf, sf] = robust_line(x(idx_linear), y(idx_linear), opts.robustMethod, opts.robustC, opts.maxIter, opts.tol);

    % diagnostics
    yhat = bf(1) + bf(2)*x(idx_linear);
    SSE  = sum((y(idx_linear) - yhat).^2);
    SST  = sum((y(idx_linear) - mean(y(idx_linear))).^2);
    R2   = 1 - SSE / max(eps, SST);

    fit = struct();
    fit.slope       = bf(2);
    fit.intercept   = bf(1);
    fit.idx_linear  = idx_linear;
    fit.cutoff_idx  = cutoff;
    fit.slope_ref   = slope_ref;
    fit.options     = opts;

    diag = struct();
    diag.residuals  = rf;
    diag.weights    = wf;
    diag.sigma      = sf;
    diag.R2         = R2;
    diag.SSE        = SSE;
    diag.SST        = SST;

end

function [b, w, r, s] = robust_line(x, y, method, c, maxIter, tol)
%ROBUST_LINE IRLS robust linear regression for y ~ a + b x
%   Returns parameters b=[a;b], final weights w, residuals r, and scale s.

    X = [ones(numel(x),1), x(:)];
    y = y(:);

    % initial OLS
    b = X\y;
    r = y - X*b;
    s = mad_scale(r);
    if s < eps, s = 1.0; end
    w = ones(size(y));

    for it = 1:maxIter
        z = r / (s*c);
        switch method
            case "huber"
                w = huber_w(z);
            case "bisquare"
                w = bisquare_w(z);
        end
        % avoid zero diagonal by flooring weights
        w = max(w, 1e-6);
        W = spdiags(w, 0, numel(w), numel(w));
        b_new = (X'*(W*X)) \ (X'*(W*y));
        if norm(b_new - b, 2) < tol*max(1,norm(b,2))
            b = b_new; break
        end
        b = b_new;
        r = y - X*b;
        s = mad_scale(r);
        if s < eps, s = 1.0; end
    end
    % final residuals with final params
    r = y - X*b;
end

function s = mad_scale(r)
%MAD_SCALE Robust scale estimate from MAD
    s = 1.4826 * mad(r, 1);
    if ~isfinite(s) || s <= 0
        s = std(r,0);
    end
    if ~isfinite(s) || s <= 0
        s = 1.0;
    end
end

function w = huber_w(z)
%HUBER_W Huber IRLS weights
    az = abs(z);
    w = ones(size(z));
    idx = az > 1;
    w(idx) = 1 ./ az(idx);
end

function w = bisquare_w(z)
%BISQUARE_W Tukey's bisquare weights
    az = abs(z);
    w = zeros(size(z));
    idx = az < 1;
    t = 1 - (az(idx)).^2;
    w(idx) = t.^2;
end

