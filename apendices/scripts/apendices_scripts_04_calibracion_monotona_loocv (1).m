% ================================================================
% CALIBRACIÓN MONÓTONA AUTOMÁTICA (rho = f(theta))
% Compara:
% 1) Lineal inversa (OLS)
% 2) Cuadrática inversa (OLS) con chequeo de monotonía
% 3) PCHIP monótono
%
% Selecciona automáticamente el mejor modelo que CUMPLA monotonía
% según RMSE_rho en validación LOOCV.
% ================================================================

clear; clc; close all;

% ---------------------------------------------------------------
% DATOS (medias por densidad)
% ---------------------------------------------------------------
rho = [0.9973; 0.9988; 1.0011; 1.0064; 1.0171]; % g/cm^3
theta = [-0.959728; -0.965887; -0.990024; -0.996329; -1.005607]; % rad

% (Opcional) incertidumbre para barras
theta_std = [0.0058; 0.0016; 0.0008; 0.0017; 0.0029];
n_rep = 5;
theta_sem = theta_std./sqrt(n_rep);

% ---------------------------------------------------------------
% PREPARACIÓN: ordenar por theta creciente (más negativo -> menos negativo)
% ---------------------------------------------------------------
[theta_s, idx] = sort(theta, 'ascend');
rho_s = rho(idx);

N = numel(theta_s);
theta_min = min(theta_s);
theta_max = max(theta_s);

% Monotonía esperada física:
% al aumentar rho, theta se hace más negativo.
% Equivalente en inversa rho=f(theta): f'(theta) < 0
expected_sign = -1; % pendiente negativa

% ---------------------------------------------------------------
% FUNCIONES auxiliares
% ---------------------------------------------------------------
rmse = @(e) sqrt(mean(e.^2));

% Evalúa monotonía densa en el dominio de theta
check_monotone_dense = @(fun, xmin, xmax, sign_expected) ...
    local_check_monotone_dense(fun, xmin, xmax, sign_expected);

% ---------------------------------------------------------------
% MODELO 1: Lineal inversa rho = a*theta + b
% ---------------------------------------------------------------
p_lin = polyfit(theta_s, rho_s, 1);
f_lin = @(th) polyval(p_lin, th);

mono_lin = check_monotone_dense(f_lin, theta_min, theta_max, expected_sign);

% LOOCV
pred_lin = nan(N,1);
for i = 1:N
    tr = true(N,1); tr(i)=false;
    p_i = polyfit(theta_s(tr), rho_s(tr), 1);
    pred_lin(i) = polyval(p_i, theta_s(i));
end
rmse_lin = rmse(pred_lin - rho_s);

% ---------------------------------------------------------------
% MODELO 2: Cuadrática inversa rho = a*theta^2 + b*theta + c
% ---------------------------------------------------------------
p_quad = polyfit(theta_s, rho_s, 2);
f_quad = @(th) polyval(p_quad, th);

mono_quad = check_monotone_dense(f_quad, theta_min, theta_max, expected_sign);

% LOOCV
pred_quad = nan(N,1);
mono_quad_cv = true; % exigimos monotonía en cada fold
for i = 1:N
    tr = true(N,1); tr(i)=false;
    p_i = polyfit(theta_s(tr), rho_s(tr), 2);
    f_i = @(th) polyval(p_i, th);
    pred_quad(i) = f_i(theta_s(i));

    % chequeo monotonía del fold
    if ~check_monotone_dense(f_i, min(theta_s(tr)), max(theta_s(tr)), expected_sign)
        mono_quad_cv = false;
    end
end
rmse_quad = rmse(pred_quad - rho_s);

% ---------------------------------------------------------------
% MODELO 3: PCHIP monótono (con datos monotónicos)
% ---------------------------------------------------------------
% Si los datos no son estrictamente monotónicos por ruido, forzamos
% monotonía mínima con "cummin" sobre rho en función de theta ascendente,
% dado que esperamos pendiente negativa.
rho_mono = rho_s;
for k = 2:N
    if rho_mono(k) > rho_mono(k-1)
        rho_mono(k) = rho_mono(k-1) - 1e-9;
    end
end

f_pchip = @(th) interp1(theta_s, rho_mono, th, 'pchip', 'extrap');

mono_pchip = check_monotone_dense(f_pchip, theta_min, theta_max, expected_sign);

% LOOCV para pchip
pred_pchip = nan(N,1);
mono_pchip_cv = true;
for i = 1:N
    tr = true(N,1); tr(i)=false;

    th_tr = theta_s(tr);
    rh_tr = rho_s(tr);

    % ordenar fold
    [th_tr, id2] = sort(th_tr, 'ascend');
    rh_tr = rh_tr(id2);

    % forzar monotonía mínima del fold
    rh_m = rh_tr;
    for k = 2:numel(rh_m)
        if rh_m(k) > rh_m(k-1)
            rh_m(k) = rh_m(k-1) - 1e-9;
        end
    end

    f_i = @(th) interp1(th_tr, rh_m, th, 'pchip', 'extrap');
    pred_pchip(i) = f_i(theta_s(i));

    if ~check_monotone_dense(f_i, min(th_tr), max(th_tr), expected_sign)
        mono_pchip_cv = false;
    end
end
rmse_pchip = rmse(pred_pchip - rho_s);

% ---------------------------------------------------------------
% RESUMEN
% ---------------------------------------------------------------
Model = ["Lineal inversa (OLS)"; ...
         "Cuadrática inversa (OLS)"; ...
         "PCHIP monótono"];
Monotono_global = [mono_lin; mono_quad; mono_pchip];
Monotono_LOOCV = [true; mono_quad_cv; mono_pchip_cv];
RMSE_LOOCV = [rmse_lin; rmse_quad; rmse_pchip];

T = table(Model, Monotono_global, Monotono_LOOCV, RMSE_LOOCV);
disp('===============================================================');
disp('COMPARACIÓN DE MODELOS MONÓTONOS (criterio LOOCV)');
disp('===============================================================');
disp(T);

% ---------------------------------------------------------------
% SELECCIÓN AUTOMÁTICA
% ---------------------------------------------------------------
valid = Monotono_global & Monotono_LOOCV;

if ~any(valid)
    warning('Ningún modelo cumplió monotonía estricta global+LOOCV. Se usará lineal inversa.');
    best_name = "Lineal inversa (OLS)";
    f_best = f_lin;
elseif sum(valid)==1
    best_idx = find(valid,1);
    best_name = Model(best_idx);
    switch best_idx
        case 1, f_best = f_lin;
        case 2, f_best = f_quad;
        case 3, f_best = f_pchip;
    end
else
    idx_valid = find(valid);
    [~,j] = min(RMSE_LOOCV(valid));
    best_idx = idx_valid(j);
    best_name = Model(best_idx);
    switch best_idx
        case 1, f_best = f_lin;
        case 2, f_best = f_quad;
        case 3, f_best = f_pchip;
    end
end

fprintf('\n===============================================================\n');
fprintf('MODELO SELECCIONADO AUTOMÁTICAMENTE\n');
fprintf('===============================================================\n');
fprintf('Mejor modelo monótono: %s\n', best_name);

switch best_name
    case "Lineal inversa (OLS)"
        fprintf('rho(theta) = %.10f*theta + %.10f\n', p_lin(1), p_lin(2));
    case "Cuadrática inversa (OLS)"
        fprintf('rho(theta) = %.10f*theta^2 + %.10f*theta + %.10f\n', ...
            p_quad(1), p_quad(2), p_quad(3));
    otherwise
        fprintf('rho(theta): interpolación PCHIP monótona por tramos.\n');
end

% ---------------------------------------------------------------
% GRÁFICA
% ---------------------------------------------------------------
figure('Name','Calibración monótona automática'); hold on; grid on;

% puntos
errorbar(theta_s, rho_s, theta_sem(idx), theta_sem(idx), ...
    'o', 'LineWidth',1.2, 'MarkerSize',7, 'DisplayName','Datos');

% curvas
thg = linspace(theta_min, theta_max, 400)';
plot(thg, f_lin(thg), '--', 'LineWidth',1.5, 'DisplayName','Lineal inversa');
plot(thg, f_quad(thg), '-', 'LineWidth',1.5, 'DisplayName','Cuadrática inversa');
plot(thg, f_pchip(thg), '-.', 'LineWidth',1.8, 'DisplayName','PCHIP monótono');

% mejor
plot(thg, f_best(thg), 'k', 'LineWidth',2.5, ...
    'DisplayName',['Seleccionado: ' char(best_name)]);

xlabel('\theta_{eq} [rad]');
ylabel('\rho [g/cm^3]');
title('Selección automática de calibración monótona');
legend('Location','best');

% ---------------------------------------------------------------
% EXPORT
% ---------------------------------------------------------------
writetable(T, 'comparacion_modelos_monotonos.csv');
fprintf('\nTabla guardada en: comparacion_modelos_monotonos.csv\n');

% ===== función local =====
function tf = local_check_monotone_dense(fun, xmin, xmax, sign_expected)
    xg = linspace(xmin, xmax, 400)';
    yg = fun(xg);
    d = diff(yg)./diff(xg);
    if sign_expected < 0
        tf = all(d < 0);
    else
        tf = all(d > 0);
    end
end