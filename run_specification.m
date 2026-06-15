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

    DutyCycleBoost = 0.72;

    sim("FullModel.slx")

    t = sys_out.time;
    sys = sys_out.Data;

    mask = t >= 0.14;
    sys_avg = mean(sys(mask));

    fprintf('Duty Cycle Chosen is %d\n', DutyCycleBoost);
    fprintf('Average sys_out = %.4f\n', sys_avg);
    fprintf('-----------------------------------\n');

%%

    for DutyCycleBoost = n

        assignin('base','DutyCycleBoost',DutyCycleBoost);

        sim("FullModel.slx")

        t = sys_out.time;
        sys = sys_out.Data;

        mask = t >= 0.14;
        sys_avg = mean(sys(mask));

        fprintf('Duty Cycle Chosen is %d\n', DutyCycleBoost);
        fprintf('Average sys_out = %.4f\n', sys_avg);
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