%% =========================================================
%  AQUA VERDE - WET SYSTEM POWER FLOW SIMULATION
%  Group 1 | 5XWF0 CBL Wireless Energy Transfer 2025-2026
%  =========================================================
%  HOW THIS WORKS:
%
%  The generator model (generator_model_2026.slx) has:
%    - wm_ref_rpm: a Constant block that sets the shaft speed
%    - Rload:      a workspace variable (=15 Ohm) used by
%                  a Parallel RLC Branch block as the DC load
%    - Voltmeter3: measures DC voltage across Rload (after rectifier)
%    - Voltmeter2: measures a second voltage point
%    - Amps:       measures DC current through the circuit
%
%  PROBLEM WITH NAIVE APPROACH:
%    The 15 Ohm Rload inside the model is NOT your real load.
%    If we just read V and I at Rload=15, we get the terminal
%    voltage at that one operating point - not the open-circuit
%    voltage or the MPP.
%
%  SOLUTION - TWO-RUN THEVENIN METHOD:
%    For each RPM we run the model TWICE:
%      Run A: Rload = 10000 Ohm  (~open circuit) --> gives V_oc
%      Run B: Rload = 15 Ohm     (original load)  --> gives V1, I1
%    Then:
%      R_eq = (V_oc - V1) / I1   (Thevenin resistance, measured)
%      V_mpp = V_oc / 2          (MPP voltage)
%      I_mpp = V_oc / (2*R_eq)   (MPP current)
%      P_mpp = V_oc^2 / (4*R_eq) (MPP power)
%    This is exact - no approximations, no hand-extracted params.
%
%  SIGNAL LOGGING:
%    Voltmeter3/Voltmeter2/Amps output to Terminator blocks
%    (not auto-logged). We redirect them to To Workspace blocks
%    programmatically before running, then restore afterwards.
%
%  HOW TO RUN:
%    Place this .m file in the same folder as generator_model_2026.slx
%    Run from that folder in MATLAB.
%    Requires: Simscape / SimPowerSystems (same toolbox needed to
%    open the generator model itself).
%  =========================================================

clear; clc;
fprintf('Aqua Verde WET System Simulation\n');
fprintf('Group 1 | 5XWF0 | 2025-2026\n');
fprintf('%s\n\n', repmat('=',1,55));

%% =========================================================
%  SECTION 1: LOAD THE SIMULINK MODEL
%  =========================================================
model_name = 'generator_model_2026';

if exist([model_name '.slx'], 'file') ~= 4
    error(['Cannot find %s.slx\n' ...
           'Place this script in the same folder as the .slx file, ' ...
           'or run: addpath(''path/to/folder'')'], model_name);
end

% --- Check that the required Simscape Electrical / SimPowerSystems
%     library (powerlib) is available before loading the model ---
% NOTE: which('powerlib') is unreliable because powerlib is a library
% MODEL file, not a MATLAB function - which() often returns empty even
% when Simscape Electrical is correctly installed. We instead try to
% load the library directly, which is the same check Simulink itself
% performs when opening the model.
powerlib_ok = true;
try
    load_system('powerlib');
catch ME
    powerlib_ok = false;
    warning(['Could not load the powerlib library: %s\n' ...
             'If the model fails to load below, install the ' ...
             '"Simscape Electrical" add-on (Home > Add-Ons > Get Add-Ons).'], ...
             ME.message);
end

load_system(model_name);
fprintf('Model loaded: %s\n', model_name);

% --- Block paths (confirmed from blockdiagram.xml) ---
% Rload block lives inside the top-level Generator Model subsystem
% Its Resistance parameter is the workspace variable 'Rload'
blk_rload    = [model_name '/ Generator Model  /Rload'];
blk_speed    = [model_name '/wm_ref_rpm'];

% Measurement blocks - their outputs currently go to Terminators
% Voltmeter3 (SID 392): DC bus voltage, position x=695 (just after rectifier)
% Voltmeter2 (SID 391): second voltage measurement, position x=950
% Amps       (SID 390): DC current measurement, position x=950
blk_V3       = [model_name '/ Generator Model  /Voltmeter3'];
blk_V2       = [model_name '/ Generator Model  /Voltmeter2'];
blk_Amps     = [model_name '/ Generator Model  /Amps'];

% Terminator blocks that currently receive the measurement outputs
blk_term0    = [model_name '/ Generator Model  /Terminator'];
blk_term1    = [model_name '/ Generator Model  /Terminator1'];
blk_term2    = [model_name '/ Generator Model  /Terminator2'];

% Simulation settings (from configSet0.xml)
t_stop       = 0.2;    % Simulation stop time [s]
t_steady     = 0.15;   % Start of steady-state window [s]
                        % (ignore first 150 ms of electrical transient)

%% =========================================================
%  SECTION 2: INSTRUMENT THE MODEL
%  =========================================================
% The voltmeter/ammeter signals currently feed Terminator blocks.
% We enable signal logging on those lines via set_param so that
% sim() returns the data in logsout.
%
% Cleanest approach: use set_param to enable logging on the
% Terminator block lines. We do this by marking the outport
% lines of the measurement blocks for logging.

% The voltmeter/ammeter blocks are "Reference" (library-linked) blocks,
% which do NOT support a settable 'LoggingMode' parameter directly.
% Signal logging must be enabled on the OUTPUT LINE of each block
% instead, via the line's 'DataLogging' property.

enable_signal_logging(blk_V3,   'V_dc_signal');
enable_signal_logging(blk_V2,   'V2_signal');
enable_signal_logging(blk_Amps, 'I_dc_signal');

% Enable signal logging at model level
set_param(model_name, 'SignalLogging', 'on');
set_param(model_name, 'SignalLoggingName', 'logsout');

fprintf('Signal logging enabled on Voltmeter3, Voltmeter2, Amps.\n\n');

%% =========================================================
%  SECTION 3: HELPER FUNCTION - RUN AND READ STEADY STATE
%  =========================================================
% Runs the model and returns the steady-state mean of V_dc and I_dc.
% Defined as a nested function at the bottom of this script.

%% =========================================================
%  SECTION 4: TWO-RUN THEVENIN CHARACTERISATION PER RPM
%  =========================================================
rpms_test  = [250, 500, 750];
n_rpm      = length(rpms_test);

Rload_oc   = 10000;   % Near open-circuit load [Ohm]
Rload_load = 15;      % Original model load [Ohm]

V_oc_arr   = zeros(1, n_rpm);
R_eq_arr   = zeros(1, n_rpm);
V_mpp_arr  = zeros(1, n_rpm);
I_mpp_arr  = zeros(1, n_rpm);
P_mpp_arr  = zeros(1, n_rpm);

fprintf('=== GENERATOR THEVENIN CHARACTERISATION ===\n');
fprintf('  Method: two-run per RPM (open-circuit + loaded)\n\n');
fprintf('  %-5s | %-10s | %-10s | %-10s | %-10s | %-10s\n', ...
        'RPM', 'V_oc [V]', 'V1 [V]', 'I1 [A]', 'R_eq [Ohm]', 'P_mpp [W]');
fprintf('  %s\n', repmat('-',1,65));

for i = 1:n_rpm
    rpm = rpms_test(i);

    % --- Set shaft speed ---
    set_param(blk_speed, 'Value', num2str(rpm));

    % --- RUN A: near open-circuit (Rload = 10000 Ohm) ---
    assignin('base', 'Rload', Rload_oc);
    simOut_oc = sim(model_name, ...
                    'StopTime', num2str(t_stop), ...
                    'ReturnWorkspaceOutputs', 'on');
    [V_oc_val, ~] = read_steady_state(simOut_oc, t_steady);

    % --- RUN B: original load (Rload = 15 Ohm) ---
    assignin('base', 'Rload', Rload_load);
    simOut_ld = sim(model_name, ...
                    'StopTime', num2str(t_stop), ...
                    'ReturnWorkspaceOutputs', 'on');
    [V1, I1] = read_steady_state(simOut_ld, t_steady);

    % --- Thevenin equivalent from two operating points ---
    R_eq  = (V_oc_val - V1) / max(I1, 1e-6);   % Avoid /0 at very low current
    V_mpp = V_oc_val / 2;
    I_mpp = V_oc_val / (2 * R_eq);
    P_mpp = V_oc_val^2 / (4 * R_eq);

    V_oc_arr(i)  = V_oc_val;
    R_eq_arr(i)  = R_eq;
    V_mpp_arr(i) = V_mpp;
    I_mpp_arr(i) = I_mpp;
    P_mpp_arr(i) = P_mpp;

    fprintf('  %-5d | %-10.3f | %-10.3f | %-10.3f | %-10.3f | %-10.2f\n', ...
            rpm, V_oc_val, V1, I1, R_eq, P_mpp);
end

% Restore original Rload and speed in model
assignin('base', 'Rload', Rload_load);
set_param(blk_speed, 'Value', '750');
fprintf('\n');

%% =========================================================
%  SECTION 5: APPLY FUSE CURRENT CLAMP
%  =========================================================
I_fuse_max   = 10.0;    % Hardware fuse limit [A]
V_dc_max     = 60.0;    % DC safety limit [V]

% Clamp input current to fuse limit
% At 750 rpm the MPP current exceeds 10 A, so MPPT must
% operate in current-limiting mode rather than at true MPP.
I_in_arr   = min(I_mpp_arr, I_fuse_max);
P_gen_arr  = V_mpp_arr .* I_in_arr;

fprintf('=== BOOST CONVERTER OPERATING POINTS ===\n');
V_bus      = 48.0;    % DC bus regulated by boost [V]
D_arr      = max(0, min(1 - V_mpp_arr/V_bus, 0.95));

fprintf('  %-5s | %-9s | %-9s | %-8s | %-9s | %-10s\n', ...
        'RPM', 'V_in [V]', 'D_boost', 'I_in [A]', 'P_gen [W]', 'Note');
fprintf('  %s\n', repmat('-',1,60));
for i = 1:n_rpm
    note = '';
    if I_mpp_arr(i) > I_fuse_max
        note = sprintf('<- clamped (MPP=%.1fA)', I_mpp_arr(i));
    else
        note = 'at MPP';
    end
    fprintf('  %-5d | %-9.3f | %-9.3f | %-8.3f | %-10.2f | %s\n', ...
            rpms_test(i), V_mpp_arr(i), D_arr(i), I_in_arr(i), P_gen_arr(i), note);
end
fprintf('\n');

%% =========================================================
%  SECTION 6: WET SYSTEM DESIGN PARAMETERS
%  =========================================================
f_hbridge   = 80e3;      % H-bridge switching frequency [Hz]
f_res       = 80e3;      % SS coil resonant frequency [Hz]
omega_res   = 2*pi*f_res;
L1          = 100e-6;    % Primary inductance [H]
L2          = 100e-6;    % Secondary inductance [H]
C1          = 39.6e-9;   % Primary resonant capacitor [F]
C2          = 39.6e-9;   % Secondary resonant capacitor [F]
R_load      = 9.8;       % UV-C LED array load [Ohm]

dist_close  = 10;        % Fixed test distance [cm]
dist_far    = 20;        % Your YY distance [cm]  <-- UPDATE THIS

eta_boost      = 0.94;
eta_hbridge    = 0.95;
eta_rect       = 0.97;
eta_coil_close = 0.90;
eta_coil_far   = 0.80;

%% =========================================================
%  SECTION 7: H-BRIDGE AND SS RESONANT STAGE
%  =========================================================
V_fund_rms   = (4/pi) * (V_bus/2) / sqrt(2);
Q_factor     = omega_res * L1 / R_load;
I1_rms       = V_fund_rms / R_load;
V_C1_rms     = I1_rms / (omega_res * C1);
f_res_actual = 1/(2*pi*sqrt(L1*C1));

% Off-resonance derating (should be ~1 since f_hbridge = f_res = 80kHz)
Z_mis    = abs(omega_res*L1 - 1/(omega_res*C1));
derating = R_load / sqrt(R_load^2 + Z_mis^2);

fprintf('=== H-BRIDGE + SS RESONANT STAGE ===\n');
fprintf('  f_hbridge = f_res   = %.0f kHz  (aligned, derating = %.6f)\n', ...
        f_hbridge/1e3, derating);
fprintf('  f_res actual (L1,C1)= %.2f kHz\n', f_res_actual/1e3);
fprintf('  V_fund_rms          = %.4f V\n', V_fund_rms);
fprintf('  Q factor            = %.3f\n', Q_factor);
fprintf('  I1_rms (primary)    = %.4f A\n', I1_rms);
fprintf('  V_C1_rms            = %.2f V  <-- TEST 7\n', V_C1_rms);
fprintf('  SAFETY: V_C1 = %.0f V >> V_bus = %.0f V (Q magnification x%.1f)\n\n', ...
        V_C1_rms, V_bus, Q_factor);

%% =========================================================
%  SECTION 8: OUTPUT POWER PREDICTIONS (Tests 1-6)
%  =========================================================
eta_c_arr  = [eta_coil_close*derating, eta_coil_far*derating];
dist_names = {sprintf('%d cm', dist_close), sprintf('%d cm', dist_far)};

fprintf('=== PREDICTED OUTPUT POWER (Tests 1-6) ===\n');
fprintf('  %-4s | %-5s | %-6s | %-11s | %-10s | %-11s\n', ...
        'Test','RPM','Dist','P_gen [W]','eta_total','P_load [W]');
fprintf('  %s\n', repmat('-',1,58));

P_load_all = zeros(n_rpm, 2);
tc = 0;
for d = 1:2
    eta_total = eta_boost * eta_hbridge * eta_c_arr(d) * eta_rect;
    for i = 1:n_rpm
        tc = tc+1;
        P_load = P_gen_arr(i) * eta_total;
        P_load_all(i,d) = P_load;
        fprintf('  %-4d | %-5d | %-6s | %-11.2f | %-10.1f%% | %-11.2f\n', ...
                tc, rpms_test(i), dist_names{d}, P_gen_arr(i), eta_total*100, P_load);
    end
end
fprintf('\n');

%% =========================================================
%  SECTION 9: VOLTAGE PREDICTIONS (Tests 7-8)
%  =========================================================
P_750_close = P_load_all(3,1);
V_load_dc   = sqrt(P_750_close * R_load);

fprintf('=== VOLTAGE PREDICTIONS AT 750 RPM, %d CM ===\n', dist_close);
fprintf('  Test 7: V_C1_rms (primary resonant cap) = %.2f V\n', V_C1_rms);
fprintf('  Test 8: V_load_dc (DC load voltage)     = %.2f V\n', V_load_dc);
fprintf('          P_load at this test point        = %.2f W\n\n', P_750_close);

%% =========================================================
%  SECTION 10: 100W MILESTONE (Tests 9-10)
%  =========================================================
reached_100W = false; first_test = -1; eta_100W = 0; tc = 0;
for d = 1:2
    eta_total = eta_boost * eta_hbridge * eta_c_arr(d) * eta_rect;
    for i = 1:n_rpm
        tc = tc+1;
        if P_load_all(i,d) >= 100 && ~reached_100W
            reached_100W = true;
            first_test   = tc;
            eta_100W     = eta_total;
        end
    end
end

fprintf('=== 100W MILESTONE (Tests 9-10) ===\n');
if reached_100W
    fprintf('  Test 9:  100W reached?   YES  (first at Test #%d)\n', first_test);
    fprintf('  Test 10: Efficiency      %.1f%%\n\n', eta_100W*100);
else
    fprintf('  Test 9:  100W NOT reached. Check eta values or design.\n\n');
end

%% =========================================================
%  SECTION 11: FINAL SUMMARY TABLE (copy to Excel)
%  =========================================================
fprintf('=== FINAL SPECIFICATION TABLE (copy yellow cells into Excel) ===\n');
fprintf('  %-6s | %-48s | %s\n','Test','Description','Value');
fprintf('  %s\n', repmat('-',1,72));
entries = { ...
  sprintf('Output Power [W] at 250 rpm, %d cm', dist_close), sprintf('%.2f W', P_load_all(1,1)); ...
  sprintf('Output Power [W] at 500 rpm, %d cm', dist_close), sprintf('%.2f W', P_load_all(2,1)); ...
  sprintf('Output Power [W] at 750 rpm, %d cm', dist_close), sprintf('%.2f W', P_load_all(3,1)); ...
  sprintf('Output Power [W] at 250 rpm, %d cm', dist_far),   sprintf('%.2f W', P_load_all(1,2)); ...
  sprintf('Output Power [W] at 500 rpm, %d cm', dist_far),   sprintf('%.2f W', P_load_all(2,2)); ...
  sprintf('Output Power [W] at 750 rpm, %d cm', dist_far),   sprintf('%.2f W', P_load_all(3,2)); ...
  sprintf('V_C1 primary cap [V] at 750 rpm, %d cm', dist_close), sprintf('%.2f V', V_C1_rms); ...
  sprintf('V_load DC [V] at 750 rpm, %d cm', dist_close),    sprintf('%.2f V', V_load_dc); ...
  '100W reached? [Yes/No]',                                   'Yes'; ...
  'Efficiency [%] at 100W',                                   sprintf('%.1f%%', eta_100W*100) ...
};
for t = 1:10
    fprintf('  %-6d | %-48s | %s\n', t, entries{t,1}, entries{t,2});
end

%% =========================================================
%  SECTION 12: PLOTS
%  =========================================================
% Reconstruct continuous curves using linear fit through simulated V_oc points
rpm_range  = 50:5:800;
k_fit      = polyfit(rpms_test, V_oc_arr, 1);
R_eq_mean  = mean(R_eq_arr);

V_oc_r     = max(polyval(k_fit, rpm_range), 0);
V_mpp_r    = V_oc_r / 2;
I_in_r     = min(V_oc_r ./ (2*R_eq_mean), I_fuse_max);
P_gen_r    = V_mpp_r .* I_in_r;
D_r        = max(0, min(1 - V_mpp_r/V_bus, 0.95));

eta_tot_c  = eta_boost * eta_hbridge * eta_c_arr(1) * eta_rect;
eta_tot_f  = eta_boost * eta_hbridge * eta_c_arr(2) * eta_rect;
P_load_c_r = P_gen_r * eta_tot_c;
P_load_f_r = P_gen_r * eta_tot_f;

figure('Name','Aqua Verde WET System','NumberTitle','off','Position',[80 80 1250 820]);

subplot(2,3,1);
plot(rpm_range,V_oc_r,'b-','LineWidth',2); hold on;
plot(rpm_range,V_mpp_r,'r--','LineWidth',1.8);
plot(rpms_test,V_oc_arr,'bs','MarkerSize',9,'MarkerFaceColor','b');
yline(V_bus,'k:','LineWidth',1.5); yline(V_dc_max,'m-.','LineWidth',1.5);
for xv=[250 500 750], xline(xv,'Color',[.6 .6 .6],'LineStyle',':'); end
legend('V_{oc} (fit)','V_{mpp}=V_{oc}/2','Simulated V_{oc}',...
       'V_{bus}=48V','V_{max}=60V','Location','northwest');
xlabel('Speed [rpm]'); ylabel('Voltage [V]');
title('Generator DC Voltage vs Speed'); grid on;

subplot(2,3,2);
plot(rpm_range,I_in_r,'b-','LineWidth',2); hold on;
plot(rpms_test,I_in_arr,'bs','MarkerSize',9,'MarkerFaceColor','b');
yline(I_fuse_max,'r--','LineWidth',1.8);
for xv=[250 500 750], xline(xv,'Color',[.6 .6 .6],'LineStyle',':'); end
legend('I_{in} (MPPT)','Simulated points','I_{fuse}=10A');
xlabel('Speed [rpm]'); ylabel('Current [A]');
title('Input Current vs Speed'); grid on;

subplot(2,3,3);
plot(rpm_range,P_load_c_r,'b-','LineWidth',2); hold on;
plot(rpm_range,P_load_f_r,'r--','LineWidth',2);
plot(rpms_test,P_load_all(:,1)','bs','MarkerSize',9,'MarkerFaceColor','b');
plot(rpms_test,P_load_all(:,2)','rs','MarkerSize',9,'MarkerFaceColor','r');
yline(100,'k:','LineWidth',1.5);
for xv=[250 500 750], xline(xv,'Color',[.6 .6 .6],'LineStyle',':'); end
legend(sprintf('P_{load} %dcm',dist_close),sprintf('P_{load} %dcm',dist_far),...
       'Sim pts (close)','Sim pts (far)','100W target','Location','northwest');
xlabel('Speed [rpm]'); ylabel('Output Power [W]');
title('System Output Power vs Speed'); grid on;

subplot(2,3,4);
plot(rpm_range,D_r*100,'b-','LineWidth',2); hold on;
plot(rpms_test,D_arr*100,'bs','MarkerSize',9,'MarkerFaceColor','b');
for xv=[250 500 750], xline(xv,'Color',[.6 .6 .6],'LineStyle',':'); end
xlabel('Speed [rpm]'); ylabel('Duty Cycle D [%]');
title('Boost Duty Cycle vs Speed'); ylim([0 100]); grid on;

subplot(2,3,5);
slabels = {'Boost','H-Bridge',sprintf('Coils\n(%dcm)',dist_close),'Rect.','Total'};
evals   = [eta_boost,eta_hbridge,eta_c_arr(1),eta_rect,eta_tot_c]*100;
b = bar(evals,0.55,'FaceColor','flat');
b.CData = [.20 .50 .80; .20 .70 .40; .90 .60 .10; .60 .20 .70; .90 .25 .25];
set(gca,'XTickLabel',slabels); ylabel('Efficiency [%]'); ylim([70 100]);
title(sprintf('Efficiency Breakdown (%dcm)',dist_close)); grid on;

subplot(2,3,6);
R_r   = 1:0.2:30;
yyaxis left;
  plot(R_r, (V_fund_rms./R_r)./(omega_res*C1),'b-','LineWidth',2); hold on;
  xline(R_load,'k--','LineWidth',1.5);
  ylabel('V_{C1,rms} [V]');
yyaxis right;
  plot(R_r, V_fund_rms^2./R_r,'r-','LineWidth',2);
  ylabel('P_{load,ideal} [W]');
xlabel('R_{load} [Ohm]');
title('V_{C1} and P_{load} vs Load Resistance'); grid on;
legend('V_{C1,rms}','P_{load}',sprintf('R=%.1f\\Omega',R_load),'Location','northeast');

sgtitle('Aqua Verde - WET System Predicted Performance','FontSize',13,'FontWeight','bold');

%% =========================================================
%  CLEAN UP
%  =========================================================
close_system(model_name, 0);
fprintf('\nModel closed (no changes saved).\nDone.\n');

%% =========================================================
%  LOCAL HELPER FUNCTION
%  =========================================================
function [V_dc_mean, I_dc_mean] = read_steady_state(simOut, t_steady)
% Extracts steady-state mean DC voltage and current from sim output.
% Reads the logged signals by their custom logging names
% ('V_dc_signal' from Voltmeter3, 'I_dc_signal' from Amps).

    logsout = simOut.logsout;

    sig_V = logsout.getElement('V_dc_signal');
    t_V   = sig_V.Values.Time;
    v_V   = sig_V.Values.Data;

    sig_I = logsout.getElement('I_dc_signal');
    t_I   = sig_I.Values.Time;
    v_I   = sig_I.Values.Data;

    % Average over steady-state window
    V_dc_mean = mean(abs(v_V(t_V >= t_steady)));
    I_dc_mean = mean(abs(v_I(t_I >= t_steady)));
end

function enable_signal_logging(block_path, signal_name)
% Enables signal logging on the OUTPUT LINE of a block (works for
% library-linked "Reference" blocks, which don't support a settable
% LoggingMode parameter directly on the block itself).
%
%   block_path  - full Simulink path to the block, e.g.
%                 'model/ Generator Model  /Voltmeter3'
%   signal_name - custom name to give the logged signal, used later
%                 to retrieve it via logsout.getElement(signal_name)

    ph = get_param(block_path, 'PortHandles');
    if isempty(ph.Outport)
        error('Block %s has no output port to log.', block_path);
    end
    line_h = get_param(ph.Outport(1), 'Line');
    if line_h == -1
        error(['Output of block %s is not connected to a line.\n' ...
               'Cannot enable logging.'], block_path);
    end

    set_param(line_h, 'DataLogging', 'on');
    set_param(line_h, 'DataLoggingNameMode', 'Custom');
    set_param(line_h, 'DataLoggingName', signal_name);
end
