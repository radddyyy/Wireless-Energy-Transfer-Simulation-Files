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

%%

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

 rpm_speed = 750;
 n = 0.1:0.1:0.95;

     for DutyCycleBoost = n

        assignin('base','DutyCycleBoost',DutyCycleBoost);

        sim("FullModel.slx")

        t = sys_out.time;
        sys = sys_out.Data;

        mask = t >= 0.018;
        sys_avg = mean(sys(mask));

        fprintf('Duty Cycle Chosen is %d\n', DutyCycleBoost);
        fprintf('Average sys_out = %.4f\n', sys_avg);
        fprintf('-----------------------------------\n');

    end