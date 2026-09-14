% ================================================================
% REPETIBILIDAD PARA DENSIDAD = 1 g/cm^3
% Comparación entre theta_eq (modelo) y promedio últimos 10 s
% ================================================================

clear; clc; close all;

% ---------------------------------------------------------------
% LISTA DE ARCHIVOS
% ---------------------------------------------------------------
files = {
    'datos_udp/imu_20260628_124822.csv'
    'datos_udp/imu_20260628_125222.csv'
    'datos_udp/imu_20260628_125418.csv'
    'datos_udp/imu_20260628_125550.csv'
    'datos_udp/imu_20260628_125724.csv'
};

theta_eq_all = zeros(length(files),1);
tau_all = zeros(length(files),1);
theta_last10_all = zeros(length(files),1);
diff_all = zeros(length(files),1);

% ---------------------------------------------------------------
% MODELO DINÁMICO
% ---------------------------------------------------------------
model_fun = @(p,t) p(1) * (1 - exp(-t./p(2)));

% ---------------------------------------------------------------
% PROCESADO DE CADA ARCHIVO
% ---------------------------------------------------------------
for i = 1:length(files)

    fprintf('\nProcesando archivo: %s\n', files{i});

    data = readtable(files{i});

    % Tiempo y señales
    t_ms = data.t_ms;
    t = (t_ms - t_ms(1)) / 1000;
    ax = data.ax; 
    ay = data.ay; 
    az = data.az; 
    gz = data.gz;

    % Corte inicial
    t_cut = 3; % segundos
    idx = t > t_cut;
    t = t(idx) - t_cut;
    ax = ax(idx); ay = ay(idx); az = az(idx); gz = gz(idx);

    dt = mean(diff(t));

    % Filtro complementario
    alpha = 0.98;
    theta_acc = atan2(ax, sqrt(ay.^2 + az.^2));
    theta = zeros(size(t));

    for k = 2:length(t)
        theta_gyro = theta(k-1) + gz(k)*dt;
        theta(k) = alpha*theta_gyro + (1-alpha)*theta_acc(k);
    end

    theta_filt = smoothdata(theta, 'movmean', 50);

    % Ajuste dinámico
    N = length(theta_filt);
    n_final = max(10, round(0.2 * N));
    theta_inf0 = mean(theta_filt(end-n_final+1:end));
    tau0 = max(0.1, (t(end)-t(1))/5);
    p0 = [theta_inf0, tau0];

    cost_fun = @(p) sum((theta_filt - model_fun(p,t)).^2);
    p_opt = fminsearch(cost_fun, p0);

    theta_eq_all(i) = p_opt(1);
    tau_all(i) = p_opt(2);

    % Promedio últimos 10 s
    T_last = 10;
    idx_last = t > (t(end) - T_last);
    theta_last10 = mean(theta_filt(idx_last));
    theta_last10_all(i) = theta_last10;

    % Diferencia
    diff_all(i) = p_opt(1) - theta_last10;

    fprintf('theta_eq (modelo) = %.6f rad\n', p_opt(1));
    fprintf('theta_media últimos 10 s = %.6f rad\n', theta_last10);
    fprintf('Diferencia = %.6f rad\n', diff_all(i));

end

% ---------------------------------------------------------------
% ESTADÍSTICOS
% ---------------------------------------------------------------
theta_mean = mean(theta_eq_all);
theta_std = std(theta_eq_all);
theta_cv = theta_std / theta_mean;

fprintf('\n=============================================\n');
fprintf('RESULTADOS PARA DENSIDAD = 1 g/cm^3\n');
fprintf('=============================================\n');
fprintf('theta medio (modelo) = %.6f rad\n', theta_mean);
fprintf('Desviación = %.6f rad\n', theta_std);
fprintf('Coef. variación = %.6f\n', theta_cv);

fprintf('\nComparación modelo vs últimos 10 s:\n');
for i = 1:length(files)
    fprintf('Exp %d: modelo = %.6f, últimos 10 s = %.6f, delta = %.6f\n', ...
        i, theta_eq_all(i), theta_last10_all(i), diff_all(i));
end

% ---------------------------------------------------------------
% EXPORTAR RESULTADOS
% ---------------------------------------------------------------
save('theta_eq_agua_comparacion.mat', ...
    'theta_eq_all','theta_last10_all','diff_all', ...
    'theta_mean','theta_std','theta_cv','tau_all');

fprintf('\nResultados guardados en theta_eq_agua_comparacion.mat\n');