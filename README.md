# Robust Understeer Gradient Estimation (MATLAB)

Self‑contained MATLAB utilities for estimating the understeer gradient (Ku) from skidpad data with noise and outliers. The approach finds the linear region of steer vs. lateral acceleration and fits a robust line. Includes a reproducible demo that synthesizes realistic data and visualizes the result.

## Features
- Robust linear‑region detection via IRLS with Huber/Bisquare weighting
- Clear diagnostics (R², residuals, weights, linear mask, cutoff index)
- Toolbox‑free (base MATLAB only)
- Minimal API for Ku estimation from arrays

## Files
- `fit_linear_region.m` — Robust linear region finder and line fit for generic `x,y` data.
- `estimate_understeer_gradient.m` — Convenience wrapper for Ku from `ay, steer` arrays.
- `demo_understeer_gradient.m` — Synthetic data demo that generates plots and prints metrics.

## Quick Start
1) Open this folder in MATLAB.
2) Run the demo:
   ```matlab
   demo_understeer_gradient
   ```
   You’ll see:
   - Estimated vs. true Ku printed to the console
   - A plot of steer vs. ay highlighting the inferred linear region and fit
   - A residual histogram for the linear segment

## API
### `estimate_understeer_gradient`
```matlab
[Ku, model, diag] = estimate_understeer_gradient(ay, steer, opts)
```
- Inputs: `ay` (g), `steer` (deg) as numeric vectors, same length.
- Output `Ku`: slope in deg/g from the detected linear region.
- `model`: struct with `slope`, `intercept`, `idx_linear` (logical mask), `cutoff_idx`, and resolved `options`.
- `diag`: diagnostics (`R2`, `SSE`, `SST`, `residuals`, `weights`).
- Options (all optional):
  - `minPtsFrac`, `minPtsAbs`, `winFrac`, `winMin`, `winMax`
  - `slopeTolAbs`, `slopeTolRel`, `resK`, `resMinAbs`
  - `robustMethod` (`"huber"`|`"bisquare"`), `robustC`, `maxIter`, `tol`

### `fit_linear_region`
```matlab
[fit, diag] = fit_linear_region(x, y, opts)
```
- General robust line fit with linear‑region detection for any `x,y` vectors.
- Returns `fit.slope`, `fit.intercept`, `fit.idx_linear`, `fit.cutoff_idx`, plus `diag` as above.

## Example (without the demo)
```matlab
% ay, steer are your measured vectors
[Ku, model, diag] = estimate_understeer_gradient(ay, steer);
fprintf('Ku = %.2f deg/g (R^2 = %.3f)\n', Ku, diag.R2);
```

## Companion Utilities (analysis_utils)
If you want to integrate this work into a larger vehicle‑dynamics codebase or run batch analyses, the following companion utilities pair well with this project:
- `analysis_utils/compute_understeer_gradient.m`
  - Adapts Ku estimation to a `car` struct/object with `car.comp.skidpad.ay/steer`.
  - Thin wrapper around the same robust linear‑region logic.
- `analysis_utils/validate_car_cell.m`
  - Validates and normalizes a `carCell` (N×M) for analyses, ensuring required fields exist and are finite; fills optional metadata with `NaN` when missing.
- `analysis_utils/fit_linear_region.m`
  - The same robust fitter in a reusable location for broader analyses.

Example integration (when those files are on your MATLAB path):
```matlab
% Clean a carCell from your application
[cars, validMask, issues] = validate_car_cell(carCell);

% Compute Ku for the first valid car
idx = find(validMask, 1);
[Ku, model, diag] = compute_understeer_gradient(cars{idx});
```
These companions are optional and not required for running the portfolio demo. For a lean portfolio repo, you can keep only the three files in this folder.

## Notes
- Minimum of ~8 points is recommended; more points improve stability.
- The linear cutoff adapts to data via residual and slope gates.
- All code here is base‑MATLAB friendly and avoids toolbox dependencies.

## Rationale
Understeer gradient is commonly estimated from the linear portion of steer vs. lateral acceleration. Real data often contains noise, drift, and outliers. This implementation automates the segment selection and uses robust regression to produce stable estimates while reporting useful diagnostics for verification.

