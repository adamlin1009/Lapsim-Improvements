% DEMO_UNDERSTEER_GRADIENT
% Synthetic demonstration of robust understeer gradient estimation.
% Generates piecewise linear+nonlinear steer vs ay data with noise/outliers
% and uses estimate_understeer_gradient (fit_linear_region) to recover Ku.

clear; close all; clc;
rng(42);

% --- generate synthetic ay (g) ---
n   = 120;
ay  = linspace(0, 1.6, n)';

% True parameters
Ku_true  = 3.2;     % deg/g (linear region slope)
a_true   = 0.5;     % deg (intercept)

% Build steer: linear up to ~0.9g, then nonlinear growth
nonlin_start = 0.9;  % g
steer = a_true + Ku_true * ay;
idx_nl = ay > nonlin_start;
steer(idx_nl) = steer(idx_nl) + 5.0 * (ay(idx_nl) - nonlin_start).^2;

% Add noise
steer = steer + 0.05*randn(size(steer));

% Inject a few outliers
oi = randperm(n, 4);
steer(oi) = steer(oi) + (-1).^[1:4]' .* (0.6 + 0.6*rand(4,1)); %#ok<RAND>

% --- estimate Ku ---
[Ku, model, diag] = estimate_understeer_gradient(ay, steer);

fprintf('True Ku = %.3f deg/g\n', Ku_true);
fprintf('Estimated Ku = %.3f deg/g (R^2 lin seg = %.3f)\n', Ku, diag.R2);
fprintf('Linear cutoff index = %d of %d (ay cutoff ~ %.2fg)\n', model.cutoff_idx, numel(ay), ay(model.cutoff_idx));

% --- plot ---
figure('Color','w'); hold on; grid on; box on;
plot(ay, steer, 'o', 'MarkerSize',4, 'DisplayName','Data');

% Highlight inferred linear region
lin_mask = model.idx_linear;
plot(ay(lin_mask), steer(lin_mask), 'ko', 'MarkerFaceColor',[0.1 0.7 0.1], 'DisplayName','Linear region');

% Plot fitted line over linear region span
ay_lin_span = [min(ay(lin_mask)), max(ay(lin_mask))];
steer_fit   = model.intercept + model.slope * ay_lin_span;
plot(ay_lin_span, steer_fit, 'LineWidth',2.0, 'Color',[0.1 0.4 0.9], 'DisplayName',sprintf('Fit: Ku=%.2f deg/g', Ku));

% Decorations
xlabel('a_y (g)'); ylabel('Steer (deg)');
title('Robust Understeer Gradient Estimation (Synthetic)');
legend('Location','northwest');

% Show residual distribution (optional)
figure('Color','w');
histogram(diag.residuals, 20);
title('Residuals (linear segment)'); xlabel('Residual (deg)'); ylabel('Count'); grid on;

