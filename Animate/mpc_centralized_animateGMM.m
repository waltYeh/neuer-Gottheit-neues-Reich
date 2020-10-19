function [failed, b_f, x_true_final] = mpc_centralized_animateGMM(fig_xy, fig_w, b0, b_nom, u_nom, L, nSteps,time_past, motionModel, obsModel,lims, show_mode)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Animate the robot's motion from start to goal
%
% Inputs:
%   figh: Figure handle in which to draw
%   plotfn: function handle to plot cov ellipse
%   b0: initial belief
%   b_nom: nominal belief trajectory
%   u_nom: nominal controls
%   L: feedback gain
%   motionModel: robot motion model
%   obsModel: observation model
% Outputs:
% failed: 0 for no collision, 1 for collision, 2 for dynamic obstacle
% detected
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% larger, less overshoot; smaller, less b-noise affects assist
P_feedback = 1;
% longer, clear wish, shorter, less overshoot
t_human_withdraw = 0.5;
comp_sel =1;
use_bad_man_speed = false;
EQUAL_WEIGHT_BALANCING = 1;
EQUAL_WEIGHT_TO_BALL_FEEDBACK = 2;
EQUAL_WEIGHT_TO_REST_FEEDBACK = 3;
BALL_WISH_WITHOUT_HUMAN_INPUT = 4;
BALL_WISH_WITH_HUMAN_INPUT = 5;
BALL_WISH_WITH_OPPOSITE_HUMAN_INPUT = 6;
REST_WISH_WITHOUT_HUMAN_INPUT = 7;
REST_WISH_WITH_HUMAN_INPUT = 8;
REST_WISH_WITH_OPPOSITE_HUMAN_INPUT = 9;
CHANGE_WISHES = 10;
% show_mode = EQUAL_WEIGHT_BALANCING;
switch show_mode
    case EQUAL_WEIGHT_BALANCING
        t_human_withdraw = 0.0;
    case EQUAL_WEIGHT_TO_BALL_FEEDBACK
        t_human_withdraw = 0.15;
        comp_sel =1;
    case EQUAL_WEIGHT_TO_REST_FEEDBACK
        t_human_withdraw = 0.3;
        comp_sel =2;        
    case BALL_WISH_WITHOUT_HUMAN_INPUT
        t_human_withdraw = 0.0;
    case BALL_WISH_WITH_HUMAN_INPUT
        t_human_withdraw = 0.7;
        comp_sel =1;
    case BALL_WISH_WITH_OPPOSITE_HUMAN_INPUT
        t_human_withdraw = 0.5;
        comp_sel =2;
    case REST_WISH_WITHOUT_HUMAN_INPUT
        t_human_withdraw = 0.0;
    case REST_WISH_WITH_HUMAN_INPUT
        t_human_withdraw = 0.7;
        comp_sel =2;
    case REST_WISH_WITH_OPPOSITE_HUMAN_INPUT
        t_human_withdraw = 0.5;
        comp_sel =1;
    case CHANGE_WISHES
        t_human_withdraw = 5;
        comp_sel =1;
        use_bad_man_speed = true;
end

%%
component_stDim = motionModel.stDim;
component_bDim = component_stDim + component_stDim^2 + 1;
shared_uDim = 2;
component_alone_uDim = motionModel.ctDim - shared_uDim;

components_amount = 2;%length(b0)/component_bDim;
%     u_man = [u(end-shared_uDim+1);u(end)]
    
% stDim = motionModel.stDim;



% mu = cell(components_amount,1);
% sig = cell(components_amount,1);
% weight = zeros(components_amount,1);
mu_save = cell(components_amount,1);
sig_save = cell(components_amount,1);
weight_save = cell(components_amount,1);
x_save = [];
x_true = [];
[mu_platf, sig_platf, weight] = b2xPw(b0(1:42), component_stDim, components_amount);
mu_assist = [b0(43);b0(44);b0(49);b0(50);b0(55);b0(56)];
for i_comp=1:components_amount
%     b0_comp = b0((i_comp-1)*component_bDim+1:i_comp*component_bDim);
%     mu{i_comp} = b0_comp(1:component_stDim);
%     for d = 1:motionModel.stDim
%         sig{i_comp}(:,d) = b0_comp(d*component_stDim+1:(d+1)*component_stDim, 1);
%     end
%     weight(i_comp) = b0_comp(end);
    if comp_sel == i_comp
        x_true = [mu_platf{i_comp};mu_assist];% + chol(sig{i_comp})' * randn(component_stDim,1);
        x_save = x_true;
    end
    mu_save{i_comp} = mu_platf{i_comp};
    sig_save{i_comp} = sig_platf{i_comp}(:);
    weight_save{i_comp} = weight(i_comp);
end

failed = 0;
b_k=b0;
for k = 1:nSteps-1

%     b = zeros(component_bDim*components_amount,1); % current belief
%     for i_comp=1:components_amount
%         b((i_comp-1)*component_bDim+1:(i_comp-1)*component_bDim+component_stDim)=mu{i_comp};
%         b((i_comp-1)*component_bDim+component_stDim+1:(i_comp-1)*component_bDim+component_stDim+component_stDim*component_stDim)=sig{i_comp};
%         b((i_comp)*component_bDim)=weight(i_comp);
%     end
%     b_
    
    if ~isempty(u_nom)
        u = u_nom(:,k) + P_feedback*L(:,:,k)*(b_k - b_nom(:,k));
        % dim is 6
        for i_u = 1:length(u)
            u(i_u)=min(lims(i_u,2), max(lims(i_u,1), u(i_u)));
        end
    end
    %% update physical part
%     processNoise = motionModel.generateProcessNoise(x_true,u);
    zeroProcessNoise = zeros(4,1);
    % here we only use the input of comp_sel, drop the other target
    % u_for_true includes one target and the assist
%     u_for_true = [u((comp_sel-1)*components_amount + 1:comp_sel*components_amount);u(end-1:end)];
    dim_xy = 2;
    n_assist = 3;
    u_assist = zeros(n_assist,dim_xy);
    for i = 1:n_assist
        u_assist(i,:) = u(end-(n_assist-i)*2-1:end-(n_assist-i)*2)';
    end
    u_all_assists = sum(u_assist,1)./3;
    u_for_true = [u((comp_sel-1)*components_amount + 1:comp_sel*components_amount);u_all_assists'];
    x_next_no_spec_human_motion = motionModel.evolve(x_true(1:4),u_for_true,zeroProcessNoise);
        
    good_man_for_ball_should_output = obsModel.getObservation(x_true,'nonoise');
    good_man_speed_angle=good_man_for_ball_should_output(1:2);
    v_man = [good_man_speed_angle(1)*cos(good_man_speed_angle(2));
                good_man_speed_angle(1)*sin(good_man_speed_angle(2))];
    
    if use_bad_man_speed
        if comp_sel ==1
            v_man=[0.7;-0.2]*0.94^(k*motionModel.dt*20)*6;
            if k*motionModel.dt>1
                v_man=[0.15;0.5]*0.94^((k-nSteps/6)*motionModel.dt*20)*6;
            end
            if k*motionModel.dt>2.6
                v_man=[-0.9;0.1]*0.94^((k-nSteps/3)*motionModel.dt*20)*6;
            end
            if k*motionModel.dt>4.5
                v_man=[0.45;-1.4]*0.94^((k-nSteps/3*2)*motionModel.dt*20)*6;
            end
        elseif comp_sel ==2
            v_man = [-1.1;1.]*0.94^(k*motionModel.dt*20)*0.3;
        end
    else
        if k*motionModel.dt>t_human_withdraw
            v_man=[0;0];
        end
    end
    
    last_human_pos = x_true(3:4);
    x_true(1:2) = x_next_no_spec_human_motion(1:2);
    x_true(3:4) = last_human_pos + motionModel.dt*v_man + motionModel.dt*u_for_true(3:4);
    simpleMotionModel=TwoDPointRobot(motionModel.dt);
    simpleObsModel=TwoDSimpleObsModel();
    x_true_assist = x_true;
    for i=1:n_assist
        x_true_assist(i*2+3:i*2+4) = simpleMotionModel.evolve(x_true(i*2+3:i*2+4),u(i*2+3:i*2+4),zeros(2,1));
    end
    x_true = x_true_assist;
        % Get observation model jacobians
    z_human_react = obsModel.getObservation(x_true(1:4),'truenoise'); % true observation
    %truely observed output is not the one modeled by ekf
    speed_man = norm(v_man);
    direction_man = atan2(v_man(2),v_man(1));
    %very problematic when human gives no more output
    if k*motionModel.dt>t_human_withdraw
        z_human_react(1:2)=[speed_man;direction_man];
    else
        z_human_react(1:2)=[speed_man;direction_man] + chol(obsModel.R_speed)' * randn(2,1);
    end
%     z_human_react(1:2)=[speed_man;direction_man] + chol(obsModel.R_speed)' * randn(2,1);
    z_assists = zeros(n_assist * dim_xy,1);
    for i=1:n_assist
        z_assists(i*2-1:i*2) = simpleObsModel.getObservation(x_true(i*2+3:i*2+4), 'truenoise');
    end
    %% now do the machine part
    z_mu = cell(components_amount);
    z_sig = cell(components_amount);
    for i_comp = 1:components_amount
        %u = [v_ball;v_rest;v_aid_man];
        u_assist = zeros(n_assist,dim_xy);
        for i = 1:n_assist
            u_assist(i,:) = u(end-(n_assist-i)*2-1:end-(n_assist-i)*2)';
        end
        u_all_assists = sum(u_assist,1)./3;
        u_for_comp = [u((i_comp-1)*components_amount + 1:i_comp*components_amount);u_all_assists'];
%         if i_comp==1
%             u_for_comp(1:2)
%         end
            % Get motion model jacobians and predict pose
    %     zeroProcessNoise = motionModel.generateProcessNoise(mu{i_comp},u_for_comp); % process noise
        zeroProcessNoise = zeros(motionModel.stDim,1);
        x_prd = motionModel.evolve(mu_platf{i_comp},u_for_comp,zeroProcessNoise); % predict robot pose
        A = motionModel.getStateTransitionJacobian(mu_platf{i_comp},u_for_comp,zeroProcessNoise);
        G = motionModel.getProcessNoiseJacobian(mu_platf{i_comp},u_for_comp,zeroProcessNoise);
        Q = motionModel.getProcessNoiseCovariance(mu_platf{i_comp},u_for_comp);
        P_prd = A*sig_platf{i_comp}*A' + G*Q*G';

        z_prd = obsModel.getObservation(x_prd,'nonoise'); % predicted observation
        zerObsNoise = zeros(length(z_human_react),1);
        H = obsModel.getObservationJacobian(mu_platf{i_comp},zerObsNoise);
        % M is eye
        M = obsModel.getObservationNoiseJacobian(mu_platf{i_comp});
    %     R = obsModel.getObservationNoiseCovariance(x,z);
    %     R = obsModel.R_est;
        % update P
        HPH = H*P_prd*H';
    %     S = H*P_prd*H' + M*R*M';
        K = (P_prd*H')/(HPH + M*obsModel.R_est*M');
        z_ratio = 1;
        if abs(z_human_react(1))<1
            z_ratio = abs(z_human_react(1));
        end
        weight_adjust = [z_ratio*weight(i_comp),z_ratio*weight(i_comp),1,1]';
%         if i_comp == 1
%             weight_adjust(1) = 0;
%         end
%         K=weight_adjust.*K;
        P = (eye(motionModel.stDim) - K*H)*P_prd;
        x = x_prd + weight_adjust.*K*(z_human_react - z_prd);
        z_mu{i_comp} = z_prd;
        z_sig{i_comp} = HPH;
        mu_platf{i_comp} = x;
        sig_platf{i_comp} = P;
    end
    
    last_w = weight;

    for i_comp = 1 : components_amount
        weight(i_comp) = last_w(i_comp)*getLikelihood(z_human_react - z_mu{i_comp}, z_sig{i_comp} + obsModel.R_w);
    end
    sum_wk=sum(weight);
    if (sum_wk > 0)
        for i_comp = 1 : components_amount
            weight(i_comp) = weight(i_comp) ./ sum_wk;
        end
    else
        weight = last_w;
    end
    for i_comp = 1 : components_amount
        weight(i_comp) = 0.99*weight(i_comp)+0.01*0.5;
    end
    if abs(z_human_react(1))<0.25
        weight = last_w;
    end
    b_plattform = xPw2b(mu_platf, sig_platf, weight, 4, 2);

    
    [b_assist1_next,~,~] = getNextEstimation(b_k(43:48),u(5:6),z_assists(1:2)...
        ,simpleMotionModel,simpleObsModel);
    [b_assist2_next,~,~] = getNextEstimation(b_k(49:54),u(7:8),z_assists(3:4)...
        ,simpleMotionModel,simpleObsModel);
    [b_assist3_next,~,~] = getNextEstimation(b_k(55:60),u(9:10),z_assists(5:6)...
        ,simpleMotionModel,simpleObsModel);
    b_k = [b_plattform;b_assist1_next;b_assist2_next;b_assist3_next];
%% now for save
    for i_comp = 1 : components_amount
        mu_save{i_comp}(:,k+1) = mu_platf{i_comp};
        sig_save{i_comp}(:,k+1) = sig_platf{i_comp}(:);
        weight_save{i_comp}(:,k+1) = weight(i_comp);
    end
    x_save(:,k+1) = x_true;
    x_true_final = x_true;
%     % final belief
    b_f = b_k;
%     b_f = zeros(component_bDim*components_amount,1); % current belief
%     for i_comp=1:components_amount
%         b_f((i_comp-1)*component_bDim+1:(i_comp-1)*component_bDim+component_stDim)=mu_platf{i_comp};
%         b_f((i_comp-1)*component_bDim+component_stDim+1:(i_comp-1)*component_bDim+component_stDim+component_stDim*component_stDim)=sig_platf{i_comp};
%         b_f((i_comp)*component_bDim)=weight(i_comp);
%     end
    
%     roboTraj(:,k) = x;
%     
%     trCov_vs_time(k+1) = trace(P);
%     
%     % if robot is in collision
%     if stateValidityChecker(x) == 0
%         figure(figh);
%         plot(roboTraj(1,:),roboTraj(2,:),'g', 'LineWidth',2);
%         drawnow;
%         warning('Robot collided :( ');
%         failed = 1;
%         return;
%     end

%     delete(rh)
%     rh = fill(mu{comp_sel}(3) + robotDisk(1,:),{comp_sel}(4) + robotDisk(2,:),'b');
%     drawResult(plotFn,b,motionModel.stDim);
%     drawnow;
    figure(fig_xy)
%     plot(x_save(1,k),x_save(2,k),'+')
    hold on
    axis equal
    plot(x_save(3,k),x_save(4,k),'+')
    hold on
    axis equal
%     plot(mu_save{1}(3,k),mu_save{1}(4,k),'bo')
    plot(mu_save{1}(1,k),mu_save{1}(2,k),'bo')
    plot(mu_save{2}(1,k),mu_save{2}(2,k),'ro')
    plot(z_human_react(3),z_human_react(4),'*')
    pointsToPlot = drawResultGMM([mu_save{1}(:,k); sig_save{1}(:,k)], motionModel.stDim);
    plot(pointsToPlot(1,:),pointsToPlot(2,:),'b')
    pointsToPlot = drawResultGMM([mu_save{2}(:,k); sig_save{2}(:,k)], motionModel.stDim);
    plot(pointsToPlot(1,:),pointsToPlot(2,:),'r')
    pointsToPlot = drawResult([b_assist1_next(1:2); b_assist1_next(3:6)], 2);
    plot(pointsToPlot(1,:),pointsToPlot(2,:),'k')
    pointsToPlot = drawResult([b_assist2_next(1:2); b_assist2_next(3:6)], 2);
    plot(pointsToPlot(1,:),pointsToPlot(2,:),'k')
    pointsToPlot = drawResult([b_assist3_next(1:2); b_assist3_next(3:6)], 2);
    plot(pointsToPlot(1,:),pointsToPlot(2,:),'k')
    
    
%     [x_nom, P_nom, w_nom] = b2xPw(b_nom(:,k), component_stDim, components_amount);
%     plot(x_save(1,k),x_save(2,k),'.')
%     hold on
%     axis equal
%     plot(x_nom{1}(3),x_nom{1}(4),'b+')
%     plot(x_nom{2}(3),x_nom{2}(4),'r+')
% %     plot(mu_save{1}(3,k),mu_save{1}(4,k),'bo')
%     plot(x_nom{1}(1),x_nom{1}(2),'bo')
%     plot(x_nom{2}(1),x_nom{2}(2),'ro')
%     
%     pointsToPlot = drawResultGMM(b_nom(1:20,k), motionModel.stDim);
%     plot(pointsToPlot(1,:),pointsToPlot(2,:),'b')
%     pointsToPlot = drawResultGMM(b_nom(22:41,k), motionModel.stDim);
%     plot(pointsToPlot(1,:),pointsToPlot(2,:),'r')
    figure(fig_w)
%     
    plot([time_past + motionModel.dt*(k-1),time_past + motionModel.dt*(k)],[weight_save{1}(k),weight_save{1}(k+1)],'-ob',[time_past + motionModel.dt*(k-1),time_past + motionModel.dt*(k)],[weight_save{2}(k),weight_save{2}(k+1)],'-ok')
    hold on
%     time_line = 0:motionModel.dt:motionModel.dt*(nSteps);
    figure(fig_w+1)
    subplot(2,2,1)
    plot(time_past + motionModel.dt*(k-1),(u(5)+u(7)+u(9))/3,'b.',time_past + motionModel.dt*(k-1),(u(6)+u(8)+u(10))/3,'r.')
    %,time_past + motionModel.dt*(k-1),u(6),'r.')
    hold on
    plot(time_past + motionModel.dt*(k-1),u(2),'+')
    
    subplot(2,2,2)
    plot(time_past + motionModel.dt*(k-1),u(5),'b.',time_past + motionModel.dt*(k-1),u(6),'r.')
    hold on
    subplot(2,2,3)
    plot(time_past + motionModel.dt*(k-1),u(7),'b.',time_past + motionModel.dt*(k-1),u(8),'r.')
    hold on
    subplot(2,2,4)
    plot(time_past + motionModel.dt*(k-1),u(9),'b.',time_past + motionModel.dt*(k-1),u(10),'r.')
    hold on
    pause(0.02);
end
if time_past<0.01
    figure(fig_w+1)
    subplot(2,2,1)
    title('Unterstützung Plattform und Förderband')
    xlabel('t(s)')
    ylabel('vel(m/s)')
%     legend('x','y','Band')
    grid
    % hold off
    subplot(2,2,2)
    title('Assistent 2')
    xlabel('t(s)')
    ylabel('vel(m/s)')
%     legend('x','y')
    grid
    % hold off
    subplot(2,2,3)
    title('Assistent 3')
    xlabel('t(s)')
    ylabel('vel(m/s)')
%     legend('x','y')
    grid
    % hold off
    subplot(2,2,4)
    title('Assistent 4')
    xlabel('t(s)')
    ylabel('vel(m/s)')
%     legend('x','y')
    grid

    % figure(1)
    % plot(x_save(1,:),x_save(2,:),'.')
    % hold on
    % axis equal
    % plot(x_save(3,:),x_save(4,:),'+')
    % hold off
    % figure(2)
    % time_line = 0:motionModel.dt:motionModel.dt*(nSteps);
    % plot(time_line,weight_save{1},'b',time_line,weight_save{2},'k')

    % figure(figh);
    % plot(roboTraj(1,:),roboTraj(2,:),'g', 'LineWidth',2);
    % drawnow;
    % failed = 0;
    figure(fig_xy)
    title('Bewegungen von Plattform, Ziel A und Ziel B')
    xlabel('x(m)')
    ylabel('y(m)')
%     legend('wahre Ziele','Plattform','Ziel A im Filter','Ziel B im Filter')
    % hold off
    figure(fig_w)
    title('Gewicht der Wünsche')
    xlabel('t(s)')
    ylabel('Gewicht')
%     legend('A','B')
[x_m,y_m] = meshgrid(1:0.5:10,-2:0.5:5);
X=1:0.5:10;
Y=-2:0.5:5;
Z = zeros(size(x_m,1),size(x_m,2));
for i=1:length(X)
    for j=1:length(Y)
        ZZ = obsModel.getObservationNoiseJacobian([0;0;X(i);Y(j)]);
        Z(j,i) = ZZ(end);
%         1/(1/norm([X(i);Y(j)]-[7;0])^2 + 1/norm([X(i);Y(j)]-[3;1])^2 + 1);
    end
end
figure(fig_xy)
surf(x_m,y_m,Z-max(max(Z))-0.5)
% legend('wahre Plattform','Ziel A','Ziel B','Messung der Plattform','Belief A','Belief B')
end
end
function [b_next,mu,sig] = getNextEstimation(b,u,z,motionModel,obsModel)
%     component_alone_uDim = obj.motionModel.ctDim - obj.shared_uDim;
%             components_amount = length(b)/component_bDim;
%             [mu, sig, weight] = b2xPw(b, obj.component_stDim, obj.components_amount);

    [mu, sig] = b2xP(b, 2);
        %u = [v_ball;v_rest;v_aid_man];
%         u_for_comp = [u((i_comp-1)*component_alone_uDim + 1:i_comp*component_alone_uDim);u(end-obj.shared_uDim+1:end)];
            % Get motion model jacobians and predict pose
    %     zeroProcessNoise = motionModel.generateProcessNoise(mu{i_comp},u_for_comp); % process noise
    zeroProcessNoise = zeros(2,1);
    x_prd = motionModel.evolve(mu,u,zeroProcessNoise); % predict robot pose
    A = motionModel.getStateTransitionJacobian(mu,u,zeroProcessNoise);
    G = motionModel.getProcessNoiseJacobian(mu,u,zeroProcessNoise);
    Q = motionModel.Q_est;%getProcessNoiseCovariance(mu{i_comp},u_for_comp);
    P_prd = A*sig*A' + G*Q*G';

    z_prd = obsModel.getObservation(x_prd,'nonoise'); % predicted observation
    zerObsNoise = zeros(length(z),1);
    H = obsModel.getObservationJacobian(mu,zerObsNoise);
    % M is eye
    M = obsModel.getObservationNoiseJacobian(mu,zerObsNoise,z);
%     R = obsModel.getObservationNoiseCovariance(x,z);
%     R = obsModel.R_est;
    % update P
    HPH = H*P_prd*H';
%     S = H*P_prd*H' + M*R*M';
    K = (P_prd*H')/(HPH + M*obsModel.R_est*M');
%                 z_ratio = 1;
%                 if abs(z(1))<1
%                     z_ratio = abs(z(1));
%                 end
%                 weight_adjust = [z_ratio*weight(i_comp),z_ratio*weight(i_comp),1,1]';
%         K=weight_adjust.*K;
    P = (eye(motionModel.stDim) - K*H)*P_prd;
    x = x_prd + K*(z - z_prd);

    mu = x;
    sig = P;
    b_next = [mu;sig(:)];

end