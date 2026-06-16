%% ===== Parameters =====
Finv = 80e3;
Fboost = 70e3;
Lp = 129.57e-6;
Lsec = Lp;
Lm = 27.27e-6;
Rp = 0.3117;
Rs = Rp;

rpm_speed = 750;
n = 0.1:0.1:0.95;

%%

    DutyCycleBoost = 0.7;

    sim("FullModel.slx")

    t_sys = sys_out.time;
    sys = sys_out.Data;
    t_incur = input_current.time;
    incur = input_current.Data;
    t_involt = input_voltage.time;
    involt = input_voltage.Data;
    t_cap = res_cap_prim.time;
    cap = res_cap_prim.Data;

    sys_mask = t_sys >= 0.14;
    incur_mask = t_incur >= 0.14;
    involt_mask = t_involt >= 0.14;
    cap_mask = t_cap >= 0.14;
    sys_avg = mean(sys(sys_mask));
    incur_avg = mean(incur(incur_mask));
    involt_avg = mean(involt(involt_mask));
    cap_avg = mean(cap(cap_mask));

    pin_avg = (incur_avg * involt_avg);
    pout_avg = (sys_avg^2)/9.8;
    eff = pout_avg/pin_avg;

    fprintf('Duty Cycle Chosen is %.4f\n', DutyCycleBoost);
    fprintf('Average Input Voltage = %.4f\n', involt_avg);
    fprintf('Average Input Current = %.4f\n', incur_avg);
    fprintf('Average Input Power = %.4f\n', pin_avg);
    fprintf('Average sys_out = %.4f\n', sys_avg);
    fprintf('Average cap = %.4f\n', cap_avg);
    fprintf('Average Output Power = %.4f\n', pout_avg);
    fprintf('Efficiency = %.4f\n', eff);
    fprintf('-----------------------------------\n');

% %%
% 
%     for DutyCycleBoost = n
% 
%         assignin('base','DutyCycleBoost',DutyCycleBoost);
% 
%             sim("FullModel.slx")
% 
%             t_sys = sys_out.time;
%             sys = sys_out.Data;
%             t_incur = input_current.time;
%             incur = input_current.Data;
%             t_involt = input_voltage.time;
%             involt = input_voltage.Data;
% 
%             sys_mask = t_sys >= 0.14;
%             incur_mask = t_incur >= 0.14;
%             involt_mask = t_involt >= 0.14;
%             sys_avg = mean(sys(sys_mask));
%             incur_avg = mean(incur(incur_mask));
%             involt_avg = mean(involt(involt_mask));
% 
%             pin_avg = (incur_avg * involt_avg);
%             pout_avg = (sys_avg^2)/9.8;
%             eff = pout_avg/pin_avg;
% 
%             fprintf('Duty Cycle Chosen is %.4f\n', DutyCycleBoost);
%             fprintf('Average Input Voltage = %.4f\n', involt_avg);
%             fprintf('Average Input Current = %.4f\n', incur_avg);
%             fprintf('Average Input Power = %.4f\n', pin_avg);
%             fprintf('Average sys_out = %.4f\n', sys_avg);
%             fprintf('Average Output Power = %.4f\n', pout_avg);
%             fprintf('Efficiency = %.4f\n', eff);
%             fprintf('-----------------------------------\n');
% 
%     end
 %%
 fprintf('NOW FOR 500RPM\n');

 rpm_speed = 250;
 n = 0.9:0.02:0.99;

     for DutyCycleBoost = n

         assignin('base','DutyCycleBoost',DutyCycleBoost);

            sim("FullModel.slx")

            t_sys = sys_out.time;
            sys = sys_out.Data;
            t_incur = input_current.time;
            incur = input_current.Data;
            t_involt = input_voltage.time;
            involt = input_voltage.Data;
        
            sys_mask = t_sys >= 0.14;
            incur_mask = t_incur >= 0.14;
            involt_mask = t_involt >= 0.14;
            sys_avg = mean(sys(sys_mask));
            incur_avg = mean(incur(incur_mask));
            involt_avg = mean(involt(involt_mask));
            
            pin_avg = (incur_avg * involt_avg);
            pout_avg = (sys_avg^2)/9.8;
            eff = pout_avg/pin_avg;
        
            fprintf('Duty Cycle Chosen is %.4f\n', DutyCycleBoost);
            fprintf('Average Input Voltage = %.4f\n', involt_avg);
            fprintf('Average Input Current = %.4f\n', incur_avg);
            fprintf('Average Input Power = %.4f\n', pin_avg);
            fprintf('Average sys_out = %.4f\n', sys_avg);
            fprintf('Average Output Power = %.4f\n', pout_avg);
            fprintf('Efficiency = %.4f\n', eff);
            fprintf('-----------------------------------\n');

     end
%%
 fprintf('NOW FOR 750RPM\n');
rpm_speed = 500;
n = 0.8:0.02:0.90;

% Preallocate arrays
N = numel(n);
DutyCycle_arr = zeros(N,1);
InputVoltage_arr = zeros(N,1);
InputCurrent_arr = zeros(N,1);
InputPower_arr = zeros(N,1);
SysOut_arr = zeros(N,1);
OutputPower_arr = zeros(N,1);
Efficiency_arr = zeros(N,1);

idx = 1;
for DutyCycleBoost = n
    assignin('base','DutyCycleBoost',DutyCycleBoost);
    sim("FullModel.slx")

    t_sys = sys_out.time;
    sys = sys_out.Data;
    t_incur = input_current.time;
    incur = input_current.Data;
    t_involt = input_voltage.time;
    involt = input_voltage.Data;

    sys_mask = t_sys >= 0.14;
    incur_mask = t_incur >= 0.14;
    involt_mask = t_involt >= 0.14;

    sys_avg = mean(sys(sys_mask));
    incur_avg = mean(incur(incur_mask));
    involt_avg = mean(involt(involt_mask));
    pin_avg = (incur_avg * involt_avg);
    pout_avg = (sys_avg^2)/9.8;
    eff = pout_avg/pin_avg;

    % Store in arrays
    DutyCycle_arr(idx) = DutyCycleBoost;
    InputVoltage_arr(idx) = involt_avg;
    InputCurrent_arr(idx) = incur_avg;
    InputPower_arr(idx) = pin_avg;
    SysOut_arr(idx) = sys_avg;
    OutputPower_arr(idx) = pout_avg;
    Efficiency_arr(idx) = eff;

    fprintf('Duty Cycle Chosen is %.4f\n', DutyCycleBoost);
    fprintf('Average Input Voltage = %.4f\n', involt_avg);
    fprintf('Average Input Current = %.4f\n', incur_avg);
    fprintf('Average Input Power = %.4f\n', pin_avg);
    fprintf('Average sys_out = %.4f\n', sys_avg);
    fprintf('Average Output Power = %.4f\n', pout_avg);
    fprintf('Efficiency = %.4f\n', eff);
    fprintf('-----------------------------------\n');

    idx = idx + 1;
end

% Save all arrays to a .mat file
save('sweep_results.mat', 'DutyCycle_arr', 'InputVoltage_arr', ...
    'InputCurrent_arr', 'InputPower_arr', 'SysOut_arr', ...
    'OutputPower_arr', 'Efficiency_arr');

% Also save as a CSV table for easy viewing
T = table(DutyCycle_arr, InputVoltage_arr, InputCurrent_arr, ...
    InputPower_arr, SysOut_arr, OutputPower_arr, Efficiency_arr, ...
    'VariableNames', {'DutyCycle','InputVoltage','InputCurrent', ...
    'InputPower','SysOut','OutputPower','Efficiency'});
writetable(T, 'sweep_results.csv');

fprintf('Results saved to sweep_results.mat and sweep_results.csv\n');