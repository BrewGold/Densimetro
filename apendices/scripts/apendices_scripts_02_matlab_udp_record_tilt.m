function matlab_udp_record_tilt()
% ===== CONFIG =====
esp_ip = "192.168.1.141";
ctrl_port = 6006;
data_port = 5005;
out_dir = "datos_udp";

if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

% ===== UDP =====
uCtrl = udpport("byte");
uData = udpport("datagram", "IPV4", "LocalPort", data_port);

% ===== ESTADO =====
t_hist = [];
ang_hist = [];
max_points = 1000;

recording = false;
rec_t_ms = [];
rec_ax = [];
rec_ay = [];
rec_az = [];
rec_gx = [];
rec_gy = [];
rec_gz = [];
rec_temp = [];
rec_ang = [];
sessionStartStr = "";

% ===== FIGURA =====
fig = figure( ...
    'Name', 'Inclinación UDP ESP32', ...
    'NumberTitle', 'off', ...
    'KeyPressFcn', @keyHandler, ...
    'CloseRequestFcn', @closeHandler);

axp = axes(fig);
hLine = plot(axp, nan, nan, 'b', 'LineWidth', 1.5);
grid(axp, 'on');
xlabel(axp, 'Tiempo [s]');
ylabel(axp, 'Ángulo [deg]');
title(axp, 'Inclinación orientativa respecto a vertical');
ylim(axp, [0 90]);

annotation(fig, 'textbox', [0.13 0.82 0.5 0.12], ...
    'String', sprintf(['Teclas:\n' ...
    's=START+grabar  x=STOP+guardar  p=PING  t=STATUS\n' ...
    '1/2/3=RATE  q=salir']), ...
    'FitBoxToText', 'on', ...
    'BackgroundColor', 'w');

disp("Controles:");
disp(" s -> START + grabar");
disp(" x -> STOP + guardar CSV");
disp(" p -> PING");
disp(" t -> STATUS");
disp(" 1 -> SET RATE 10");
disp(" 2 -> SET RATE 50");
disp(" 3 -> SET RATE 100");
disp(" q -> salir");

running = true;
while running && isvalid(fig)
    pause(0.01);

    % ===== respuestas de control =====
    if uCtrl.NumBytesAvailable > 0
        msg = char(read(uCtrl, uCtrl.NumBytesAvailable, "uint8"));
        fprintf("CTRL RESP: %s\n", strtrim(msg));
    end

    % ===== datagramas de datos =====
    while uData.NumDatagramsAvailable > 0
        d = read(uData, 1, "string");
        line = strtrim(d.Data);

        vals = sscanf(line, '%f,%f,%f,%f,%f,%f,%f,%f');
        if numel(vals) ~= 8
            continue;
        end

        t_ms = vals(1);
        ax = vals(2);
        ay = vals(3);
        az = vals(4);
        gx = vals(5);
        gy = vals(6);
        gz = vals(7);
        temp = vals(8);

        % ===== ángulo orientativo =====
        ang_deg = atan2d(sqrt(ax^2 + ay^2), abs(az));

        % ===== gráfico =====
        t_hist(end+1) = t_ms / 1000; %#ok<AGROW>
        ang_hist(end+1) = ang_deg;   %#ok<AGROW>

        if numel(t_hist) > max_points
            t_hist = t_hist(end-max_points+1:end);
            ang_hist = ang_hist(end-max_points+1:end);
        end

        % ===== registro =====
        if recording
            rec_t_ms(end+1,1) = t_ms; %#ok<AGROW>
            rec_ax(end+1,1) = ax;     %#ok<AGROW>
            rec_ay(end+1,1) = ay;     %#ok<AGROW>
            rec_az(end+1,1) = az;     %#ok<AGROW>
            rec_gx(end+1,1) = gx;     %#ok<AGROW>
            rec_gy(end+1,1) = gy;     %#ok<AGROW>
            rec_gz(end+1,1) = gz;     %#ok<AGROW>
            rec_temp(end+1,1) = temp; %#ok<AGROW>
            rec_ang(end+1,1) = ang_deg; %#ok<AGROW>
        end
    end

    % ===== actualizar gráfica =====
    if ~isempty(t_hist) && isvalid(fig) && isgraphics(hLine)
        set(hLine, 'XData', t_hist, 'YData', ang_hist);
        xlim(axp, [max(0, t_hist(end)-10), max(10, t_hist(end))]);
        drawnow limitrate;
    end

    running = isvalid(fig);
end

% ===== CALLBACKS =====
    function keyHandler(~, event)
        switch event.Key
            case 's'
                sendCmd("START");

                t_hist = [];
                ang_hist = [];

                rec_t_ms = [];
                rec_ax = [];
                rec_ay = [];
                rec_az = [];
                rec_gx = [];
                rec_gy = [];
                rec_gz = [];
                rec_temp = [];
                rec_ang = [];

                sessionStartStr = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
                recording = true;

                fprintf("Grabación iniciada: %s\n", sessionStartStr);

            case 'x'
                sendCmd("STOP");

                if recording
                    recording = false;
                    saveRecording();
                else
                    disp("No había grabación activa.");
                end

            case 'p'
                sendCmd("PING");

            case 't'
                sendCmd("STATUS");

            case '1'
                sendCmd("SET RATE 10");

            case '2'
                sendCmd("SET RATE 50");

            case '3'
                sendCmd("SET RATE 100");

            case 'q'
                if isvalid(fig)
                    delete(fig);
                end
        end
    end

    function sendCmd(cmd)
        cmd_char = char(cmd);
        write(uCtrl, uint8(cmd_char), "uint8", esp_ip, ctrl_port);
        fprintf("CMD -> %s\n", cmd_char);
    end

    function saveRecording()
        if isempty(rec_t_ms)
            disp("No hay muestras para guardar.");
            return;
        end

        T = table( ...
            rec_t_ms, rec_ax, rec_ay, rec_az, ...
            rec_gx, rec_gy, rec_gz, rec_temp, rec_ang, ...
            'VariableNames', {'t_ms','ax','ay','az','gx','gy','gz','temp','ang_deg'});

        if strlength(sessionStartStr) == 0
            sessionStartStr = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
        end

        filename = fullfile(out_dir, "imu_" + sessionStartStr + ".csv");
        writetable(T, filename);

        fprintf("CSV guardado: %s\n", filename);
        fprintf("Muestras guardadas: %d\n", height(T));
    end

    function closeHandler(~, ~)
        try
            write(uCtrl, uint8('STOP'), "uint8", esp_ip, ctrl_port);
        catch
        end

        if recording
            recording = false;
            saveRecording();
        end

        if isvalid(fig)
            delete(fig);
        end
    end
end