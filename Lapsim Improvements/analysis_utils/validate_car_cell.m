function [cars, validMask, issues] = validate_car_cell(carCell, opts)
%VALIDATE_CAR_CELL Validate and normalize a carCell input for analyses.
%   [cars, validMask, issues] = VALIDATE_CAR_CELL(carCell, opts)
%
%   - Accepts N-by-M cell arrays or vectors; uses first column by default.
%   - Ensures required fields exist and are numeric/finite.
%   - Normalizes ay/steer to column vectors.
%   - Fills optional fields (camber compliance, mass) with NaN if missing.
%
%   opts.firstColumnOnly (default true)
%   opts.minSkidpadPoints (default 8)
%
%   Outputs:
%     cars      : cleaned 1-by-K cell array of car structs/objects
%     validMask : logical mask of length K with validity per entry
%     issues    : 1-by-K cell of string arrays describing problems

    arguments
        carCell
        opts.firstColumnOnly (1,1) logical = true
        opts.minSkidpadPoints (1,1) double {mustBePositive} = 8
    end

    if ~iscell(carCell)
        carCell = {carCell};
    end

    if ismatrix(carCell) && opts.firstColumnOnly && size(carCell,2) > 1
        carCell = carCell(:,1);
    end

    % Flatten to row vector of cells for downstream simplicity
    carCell = carCell(:).';

    K = numel(carCell);
    cars = cell(1,K);
    validMask = false(1,K);
    issues = cell(1,K);

    for i = 1:K
        issues{i} = strings(0,1);
        c = carCell{i};
        if isempty(c)
            issues{i}(end+1) = "Empty car entry"; %#ok<AGROW>
            cars{i} = c; continue
        end

        % Verify required nested fields exist
        [ok_sp, sp] = get_nested(c, {'comp','skidpad'});
        if ~ok_sp
            issues{i}(end+1) = "Missing comp.skidpad"; %#ok<AGROW>
            cars{i} = c; continue
        end
        [ok_ay, ay] = get_nested(sp, {'ay'});
        [ok_st, st] = get_nested(sp, {'steer'});
        if ~ok_ay || ~ok_st
            if ~ok_ay, issues{i}(end+1) = "Missing skidpad.ay"; end %#ok<AGROW>
            if ~ok_st, issues{i}(end+1) = "Missing skidpad.steer"; end %#ok<AGROW>
            cars{i} = c; continue
        end

        % Validate arrays
        if ~(isnumeric(ay) && isvector(ay) && all(isfinite(ay)))
            issues{i}(end+1) = "Invalid skidpad.ay (must be finite numeric vector)"; %#ok<AGROW>
        end
        if ~(isnumeric(st) && isvector(st) && all(isfinite(st)))
            issues{i}(end+1) = "Invalid skidpad.steer (must be finite numeric vector)"; %#ok<AGROW>
        end

        if numel(ay) < opts.minSkidpadPoints || numel(st) < opts.minSkidpadPoints
            issues{i}(end+1) = "Insufficient skidpad points"; %#ok<AGROW>
        end

        % Normalize orientation to column vectors where possible
        try
            sp.ay    = ay(:);
            sp.steer = st(:);
            c = set_nested(c, {'comp','skidpad'}, sp);
        catch
            % ignore if object not assignable
        end

        % Optional metadata: ensure fields exist (NaN if missing)
        [okF,~] = get_nested(c, {'camber_compliance_f'});
        [okR,~] = get_nested(c, {'camber_compliance_r'});
        [okM,~] = get_nested(c, {'M'});
        if ~okF, c = set_nested_safe(c, {'camber_compliance_f'}, NaN); end
        if ~okR, c = set_nested_safe(c, {'camber_compliance_r'}, NaN); end
        if ~okM, c = set_nested_safe(c, {'M'}, NaN); end

        cars{i} = c;
        validMask(i) = isempty(issues{i});
    end
end

function [ok, val] = get_nested(s, keys)
%GET_NESTED Access nested field/prop for struct or object.
    ok = true; val = s;
    for k = 1:numel(keys)
        key = keys{k};
        if isstruct(val)
            if isfield(val, key)
                val = val.(key);
            else
                ok = false; val = []; return
            end
        elseif isobject(val)
            if isprop(val, key)
                val = val.(key);
            else
                ok = false; val = []; return
            end
        else
            ok = false; val = []; return
        end
    end
end

function s = set_nested(s, keys, v)
%SET_NESTED Set nested field for structs.
    assert(isstruct(s), 'set_nested supports struct only');
    switch numel(keys)
        case 1
            s.(keys{1}) = v;
        otherwise
            k = keys{1};
            if ~isfield(s, k) || ~isstruct(s.(k))
                s.(k) = struct();
            end
            s.(k) = set_nested(s.(k), keys(2:end), v);
    end
end

function s = set_nested_safe(s, keys, v)
%SET_NESTED_SAFE Best-effort setter for struct or object; no-ops on failure.
    try
        if isstruct(s)
            s = set_nested(s, keys, v);
        elseif isobject(s)
            % Attempt property assignment only for last key
            if numel(keys) == 1 && isprop(s, keys{1})
                s.(keys{1}) = v;
            end
        end
    catch
        % swallow
    end
end

