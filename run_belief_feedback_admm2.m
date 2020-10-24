%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Demo for a 2D belief space planning scenario 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function run_belief_feedback_admm2()
%% this file added lambda_b, which is not used, others are the same as run_belief_admm
addpath(genpath('./'));
clear
close all
% FigList = findall(groot, 'Type', 'figure');
% for iFig = 1:numel(FigList)
%     try
%         clf(FigList(iFig));
%     catch
%         % Nothing to do
%     end
% end
EQUAL_WEIGHT_BALANCING = 1;
EQUAL_WEIGHT_TO_BALL_FEEDBACK = 2;
EQUAL_WEIGHT_TO_REST_FEEDBACK = 3;
BALL_WISH_WITHOUT_HUMAN_INPUT = 4;
BALL_WISH_WITH_HUMAN_INPUT = 5;
BALL_WISH_WITH_OPPOSITE_HUMAN_INPUT = 6;
REST_WISH_WITHOUT_HUMAN_INPUT = 7;
REST_WISH_WITH_HUMAN_INPUT = 8;
REST_WISH_WITH_OPPOSITE_HUMAN_INPUT = 9;
show_mode = BALL_WISH_WITHOUT_HUMAN_INPUT;
switch show_mode
    case EQUAL_WEIGHT_BALANCING
        weight_a1 = 0.5;
        weight_a2 = 0.5;
    case EQUAL_WEIGHT_TO_BALL_FEEDBACK
        weight_a1 = 0.5;
        weight_a2 = 0.5;
    case EQUAL_WEIGHT_TO_REST_FEEDBACK
        weight_a1 = 0.5;
        weight_a2 = 0.5;        
    case BALL_WISH_WITHOUT_HUMAN_INPUT
        weight_a1 = 0.99;
        weight_a2 = 0.01;
    case BALL_WISH_WITH_HUMAN_INPUT
        weight_a1 = 0.95;
        weight_a2 = 0.05;
    case BALL_WISH_WITH_OPPOSITE_HUMAN_INPUT
        weight_a1 = 0.95;
        weight_a2 = 0.05;
    case REST_WISH_WITHOUT_HUMAN_INPUT
        weight_a1 = 0.01;
        weight_a2 = 0.99;
    case REST_WISH_WITH_HUMAN_INPUT
        weight_a1 = 0.05;
        weight_a2 = 0.95;
    case REST_WISH_WITH_OPPOSITE_HUMAN_INPUT
        weight_a1 = 0.05;
        weight_a2 = 0.95;
end
direct_exchange=false;
dual_update_period =1;

%% tuned parameters
mu_a1 = [8.5, 0.0, 5.0, 0.0]';
mu_a2 = [3, 0.8, 5.0, 0.0]';
% mu_b = [4, -1.0]';
% mu_c = [4., 1.0]';
% mu_d = [6.0, 1.0]';
mu_b = [5.2, -1.3]';
mu_c = [4.2, 1.8]';
mu_d = [7.0, 1.5]';
mu_e = [6.0, 4]';
mu_f = [6, -2]';
sig_a1 = diag([0.01, 0.01, 0.1, 0.1]);%sigma
sig_a2 = diag([0.01, 0.01, 0.1, 0.1]);
sig_b = diag([0.02, 0.02]);%sigma
sig_c = diag([0.02, 0.02]);
sig_d = diag([0.02, 0.02]);
sig_e = diag([0.02, 0.02]);
sig_f = diag([0.02, 0.02]);
% weight_1 = 0.9;
% weight_2 = 0.1;
dt = 0.05;
horizon = 2.5;
mpc_update_period = 2.5;
simulation_time = 2.5;

%% 

t0 = 0;
tspan = t0 : dt : horizon;
horizonSteps = length(tspan);
tspan_btw_updates = t0 : dt : mpc_update_period;
update_steps = length(tspan_btw_updates);
simulation_steps = simulation_time/mpc_update_period;

% mm = HumanMind(dt); % motion model

% om = HumanReactionModel(); % observation model


n_agent = 6;
sd = [2  3 4 5 4];%edges start from
td = [1  1 1 1 6];%edges go to
nom_formation_1=[-1,-1;
    %-2,0;
    -1,1;
    1,1;
    0,0;
    0,0];
nom_formation_2=[1,-1;
    %-2,0;
    -1,1;
    1,1;
    0,0;
    0,0];%z formation
%control cost of node sd in opt of td
rii_control = ones(n_agent,1)*0.8;
incoming_edges = zeros(n_agent,n_agent);
EdgeTable = table([sd' td'],nom_formation_1,nom_formation_2,'VariableNames',{'EndNodes' 'nom_formation_1' 'nom_formation_2'});

NodeTable = table(incoming_edges,rii_control,'VariableNames',{'incoming_edges' 'rii_control'});
commDiGr = digraph(EdgeTable,NodeTable);
for idx=1:n_agent
    incoming_nbrs_idces = predecessors(commDiGr,idx)';
    for j = incoming_nbrs_idces
        if isempty(j)
            continue
        end
        RowIdx = ismember(commDiGr.Edges.EndNodes, [j,idx],'rows');
        [rId, cId] = find( RowIdx ) ;
        commDiGr.Nodes.incoming_edges(idx,j)=rId;
    end
end

interf_sd = [2 3 4 5 5 5 5 6 6 6 6 2 3 4 2 3 4 5];
interf_td = [1 1 1 1 2 3 4 2 3 4 5 5 5 5 6 6 6 6];
nom_formation_1 = [nom_formation_1;zeros(length(interf_sd)-5,2)];
nom_formation_2 = [nom_formation_2;zeros(length(interf_sd)-5,2)];
EdgeTable = table([interf_sd' interf_td'],nom_formation_1,nom_formation_2,'VariableNames',{'EndNodes' 'nom_formation_1' 'nom_formation_2'});
rii_control = ones(n_agent,1)*0.8;
incoming_edges = zeros(n_agent,n_agent);
NodeTable = table(incoming_edges,rii_control,'VariableNames',{'incoming_edges' 'rii_control'});
interfDiGr = digraph(EdgeTable,NodeTable);
for idx=1:n_agent
    incoming_nbrs_idces = predecessors(interfDiGr,idx)';
    for j = incoming_nbrs_idces
        if isempty(j)
            continue
        end
        RowIdx = ismember(interfDiGr.Edges.EndNodes, [j,idx],'rows');
        [rId, cId] = find( RowIdx ) ;
        interfDiGr.Nodes.incoming_edges(idx,j)=rId;
    end
end

% commGr = graph(comm_sd,comm_td);
% adjGr = full(adjacency(commGr));% full transfers sparse to normal matrix

agents = cell(size(commDiGr.Nodes,1),1);
belief_dyns = {@(b, u)beliefDynamicsGMM(b, u,HumanMind(dt),HumanReactionModel()); 
    @(b, u)beliefDynamicsSimpleAgent(b, u, TwoDPointRobot(dt),TwoDSimpleObsModel()); 
    @(b, u)beliefDynamicsSimpleAgent(b, u, TwoDPointRobot(dt),TwoDSimpleObsModel()); 
    @(b, u)beliefDynamicsSimpleAgent(b, u, TwoDPointRobot(dt),TwoDSimpleObsModel());
    @(b, u)beliefDynamicsSimpleAgent(b, u, TwoDPointRobot(dt),TwoDSimpleObsModel());
    @(b, u)beliefDynamicsSimpleAgent(b, u, TwoDPointRobot(dt),TwoDSimpleObsModel())};
agents{1} = AgentPlattformAdmm(dt,horizonSteps,1,belief_dyns);
agents{2} = AgentAssistAdmm(dt,horizonSteps,2,belief_dyns);
agents{3} = AgentAssistAdmm(dt,horizonSteps,3,belief_dyns);
agents{4} = AgentAssistAdmm(dt,horizonSteps,4,belief_dyns);
agents{5} = AgentComplementAdmm(dt,horizonSteps,5,belief_dyns);
agents{6} = AgentBypassAdmm(dt,horizonSteps,6,belief_dyns);
% agents{2} = AgentBelt(dt,horizonSteps,2);
% agents{3} = AgentCrane(dt,horizonSteps,3);
% agents{4} = AgentCrane(dt,horizonSteps,4);

%% Setup start and goal/target state

u_guess=cell(size(commDiGr.Nodes,1),size(commDiGr.Nodes,1));
for i=1:size(commDiGr.Nodes,1)
    u_guess{i,1} = zeros(agents{1}.total_uDim,horizonSteps-1);
    u_guess{i,1}(5,:) = (mu_a1(1)-mu_a1(3)-0.1)/horizon;
    % -0.1 to avoid bad matrix condition caused by Jacobian of human
    % reaction model
    u_guess{i,1}(6,:) = (mu_a1(2)-mu_a1(4)-0.1)/horizon;
    u_guess{i,2} = zeros(agents{2}.total_uDim,horizonSteps-1);
    u_guess{i,2}(1,:) = u_guess{i,1}(5,:);
    u_guess{i,2}(2,:) = u_guess{i,1}(6,:)+0.5;
    u_guess{i,3} = zeros(agents{3}.total_uDim,horizonSteps-1);
    u_guess{i,3}(1,:) = u_guess{i,1}(5,:);
    u_guess{i,3}(2,:) = u_guess{i,1}(6,:)+0.5;
    u_guess{i,4} = zeros(agents{4}.total_uDim,horizonSteps-1);
    u_guess{i,4}(1,:) = u_guess{i,1}(5,:);
    u_guess{i,4}(2,:) = u_guess{i,1}(6,:)+0.5;
    u_guess{i,5} = zeros(agents{5}.total_uDim,horizonSteps-1);
    u_guess{i,5}(1,:) = -0.4;
    u_guess{i,5}(2,:) = -1;
    u_guess{i,6} = zeros(agents{6}.total_uDim,horizonSteps-1);
    u_guess{i,6}(1,:) = 0;
    u_guess{i,6}(2,:) = -2;

end
% for i=1:size(commDiGr.Nodes,1)
%     u_guess{i,1} = zeros(agents{1}.total_uDim,horizonSteps-1);
%     u_guess{i,1}(5,:) = 0;
%     u_guess{i,1}(6,:) = 0;
%     u_guess{i,2} = zeros(agents{2}.total_uDim,horizonSteps-1);
%     u_guess{i,2}(1,:) = 0;
%     u_guess{i,2}(2,:) = 0;
%     u_guess{i,3} = zeros(agents{3}.total_uDim,horizonSteps-1);
%     u_guess{i,3}(1,:) = 0;
%     u_guess{i,3}(2,:) = 0;
%     u_guess{i,4} = zeros(agents{4}.total_uDim,horizonSteps-1);
%     u_guess{i,4}(1,:) = 0;
%     u_guess{i,4}(2,:) = 0;
% end
% initial guess, less iterations needed if given well
% guess all agents for every agent, 4x4 x uDim x horiz

b0=cell(size(commDiGr.Nodes,1),size(commDiGr.Nodes,1));
% this is a 2D cell because each agent has different format of belief
% states
% each agent holds the belief of other agents, but in a later version,
% this can be limited to neighbors of interference graph
for i=1:size(commDiGr.Nodes,1)
    %{4x4}x6
    b0{i,1} = [mu_a1;sig_a1(:);weight_a1;mu_a2;sig_a2(:);weight_a2];
    b0{i,2} = [mu_b;sig_b(:)];
    b0{i,3} = [mu_c;sig_c(:)];
    b0{i,4} = [mu_d;sig_d(:)];
    b0{i,5} = [mu_e;sig_e(:)];
    b0{i,6} = [mu_f;sig_f(:)];
end
%????????????????
% true states of agents are 2D position vectors
x_true = zeros(size(commDiGr.Nodes,1)+1,agents{3}.motionModel.stDim);
% we select component 1 as true goal
% if show_mode>6
%     x_true(1,:)=mu_a2(3:4);
% else
    x_true(1,:)=mu_a1(3:4);%plattform
% end
x_true(2,:)=mu_b;
x_true(3,:)=mu_c;
x_true(4,:)=mu_d;
if show_mode<7 && show_mode~=3
    x_true(5,:)=mu_a1(1:2);
else
    x_true(5,:)=mu_a2(1:2);
end
x_true(6,:)=mu_e;
x_true(7,:)=mu_f;
%% these are old codes remained
Op.plot = -1; % plot the derivatives as well

% prepare and install trajectory visualization callback
line_handle = line([0 0],[0 0],'color','r','linewidth',2);
plotFn = @(x) set(line_handle,'Xdata',x(1,:),'Ydata',x(2,:));
Op.plotFn = plotFn;
already_com = false;
%% === run the optimization
for i_sim = 1:simulation_steps
    time_past = (i_sim-1) * mpc_update_period;
    u = cell(size(commDiGr.Nodes,1),size(commDiGr.Nodes,1));
    b = cell(size(commDiGr.Nodes,1),size(commDiGr.Nodes,1));
    L_opt = cell(size(commDiGr.Nodes,1),1);
    cost = cell(size(commDiGr.Nodes,1),1);
    finished = cell(size(commDiGr.Nodes,1),1);
    for i = 1:size(commDiGr.Nodes,1)
        finished{i}= false;
    end
    Dim_lam_in_xy = 2;
    lam_d = zeros(size(commDiGr.Nodes,1)-3,Dim_lam_in_xy,horizonSteps);
    lam_b = zeros(size(commDiGr.Nodes,1)-3,Dim_lam_in_xy,horizonSteps);
    lam_up=zeros(1,Dim_lam_in_xy,horizonSteps-1);
    lam_c = zeros(1,Dim_lam_in_xy,horizonSteps);
    lam_w = cell(size(commDiGr.Nodes,1),1);% initialize lam_w for all agents
    % although some will not function due to limited graph connectivity
    for i=1:size(commDiGr.Nodes,1)
        lam_w{i} = zeros(size(commDiGr.Nodes,1),Dim_lam_in_xy,horizonSteps-1);%(4.32a)
    end
    last_cost_without_w=zeros(size(commDiGr.Nodes,1),1);
    sum_cost_without_w=zeros(size(commDiGr.Nodes,1),1);
    u=u_guess;
    last_u = cell(size(commDiGr.Nodes,1),size(commDiGr.Nodes,1));
    for i = 1:size(commDiGr.Nodes,1)
        [b_rollout,costs]=agents{i}.rollout(interfDiGr,b0(i,:), u_guess(i,:));
        for n_i=1:size(commDiGr.Nodes,1)
            b{i,n_i} = b_rollout{n_i};
        end
        % do an update after the first roll out
        noFeedback = zeros(agents{i}.total_uDim,size(b0{i,i},1),horizonSteps-1);
        agents{i}.updatePolicy(b(i,:),u(i,:),noFeedback);
    end

    tic
    
    %%
    for iter = 1:15
        if iter == 1
            for i = 2:size(commDiGr.Nodes,1)
                for j = 1:size(commDiGr.Nodes,1)
                    u{i,j} = [];
                    b{i,j} = [];
                end
                cost{i} = [];
                agents{i}.rho.rho_d = 0.4;
                agents{i}.rho.rho_up = 0.1;
                agents{i}.rho.rho_c = 100;
                agents{i}.rho.rho_w = 1;
            end
            agents{1}.rho.rho_d = 0.0;
            agents{1}.rho.rho_up =0.0;
            agents{1}.rho.rho_c = 100;
            agents{1}.rho.rho_w = 1;
%         elseif iter <= 3
%             for i = 1:size(commDiGr.Nodes,1)
%                 agents{i}.rho_d = 0;
%                 agents{i}.rho_up = 0.0;
%             end
%         elseif iter<=25
%             for i = 1:size(commDiGr.Nodes,1)
%                 agents{i}.rho_d = 2.5;
%                 agents{i}.rho_up = 0.0;
%             end
        else
            for i = 2:size(commDiGr.Nodes,1)
                agents{i}.rho.rho_d = 0.4;
                agents{i}.rho.rho_up = 0.1;
                agents{i}.rho.rho_c = 100;
                agents{i}.rho.rho_w = 1;
            end
            agents{1}.rho.rho_d = 0.0;
            agents{1}.rho.rho_up =0.0;
            agents{1}.rho.rho_c = 100;
            agents{1}.rho.rho_w = 1;
        end
        
        if mod(iter,dual_update_period)==0
            last_u = u;
            for i = 1:size(interfDiGr.Nodes,1)
                incoming_nbrs_idces = predecessors(interfDiGr,i)';
                for m_underindex=1:size(interfDiGr.Nodes,1)
                    diff_u_m = zeros(Dim_lam_in_xy,size(u{i,m_underindex},2));
                    for s = incoming_nbrs_idces
                        if m_underindex == 1
                            diff_u_m = diff_u_m + (u{i,m_underindex}(5:6,:)-u{s,m_underindex}(5:6,:));
                            agents{i}.last_u_from_com{s,m_underindex}=u{s,m_underindex}(5:6,:);
                        else
                            diff_u_m = diff_u_m + (u{i,m_underindex}-u{s,m_underindex});
                            agents{i}.last_u_from_com{s,m_underindex}=u{s,m_underindex};
                        end
                        % in one row of old_u, they are the u^j_i, others est
                        % about my action
                        already_com=true;
                    end
                    lam_w{i}(m_underindex,:,:)=squeeze(lam_w{i}(m_underindex,:,:))+agents{i}.rho_w*diff_u_m;%(4.32b)
                    % in the first iteration iter==1, lam_w remains zero,
                    % because guess is identical, diff_u_m = 0
                end
            end
        end
%% iLQG
        for i = 1:size(commDiGr.Nodes,1)
            if 1%finished{i}~=true
                lam.lam_d=lam_d;
%                 lam.lam_b=lam_b;
                lam.lam_up=lam_up;
                lam.lam_c=lam_c;
                lam.lam_w=lam_w;
                cost_last{i}=cost{i};
                [bi,ui,cost{i},L_opt{i},~,~, finished{i}] ...
                    = agents{i}.iLQG_one_it...
                    (interfDiGr, b0(i,:), Op, iter,u_guess(i,:),...
                    lam,u(i,:),b(i,:), cost_last{i},already_com);
%                 for j=1:size(commDiGr.Nodes,1)
%                     %update all the est of u and b of agent i itself
%                     u{i,j} = ui{j};%only ui{i} is different from u_guess
%                     b{i,j} = bi{j};
%                 end
                u{i,i} = ui{i};
                b{i,i} = bi{i};

                if i<5%update the team robots exactly without slackness
                    for j=1:4%size(commDiGr.Nodes,1)
    %                     if j~=i
                            u{j,i} = ui{i};
                            b{j,i} = bi{i};
                            if iter ==1
                                u_guess{j,i} = ui{i};
                            end
    %                     end
                    end
                end
                %% estimations of collision neighbors                
                incoming_nbrs_idces = predecessors(interfDiGr,i)';

                for j=1:size(interfDiGr.Nodes,1)
                    if i==j
                        continue;
                    end
                    if i<5 && j<5
                        continue;
                    end
                    sum_last_com_t_i_s_j=0;
                    for s=incoming_nbrs_idces
                        if j==1
                            last_u_ij = last_u{i,j}(5:6,:);
                            last_u_sj = last_u{s,j}(5:6,:);
                        else
                            last_u_ij = last_u{i,j};
                            last_u_sj = last_u{s,j};
                        end
                        sum_last_com_t_i_s_j = sum_last_com_t_i_s_j+0.5*(last_u_ij+last_u_sj);
                    end
                    if agents{i}.rho_w~=0
                        if length(incoming_nbrs_idces)~=0
                            u_ij=1/length(incoming_nbrs_idces)*(sum_last_com_t_i_s_j-squeeze(lam_w{i}(j,:,:))/2/agents{i}.rho_w);
                            %(4.31)
                            if j==1
                                u{i,j}(5:6,:)=u_ij;
                            else
                                u{i,j}=u_ij;%no effect in first iteration because we use the last_u not u from iLQG
                            end
                        end
                    end
                end
                [b_rollout,costs]=agents{i}.rollout(interfDiGr,b0(i,:), u(i,:));
                for j=incoming_nbrs_idces
                    b{i,j} = b_rollout{j};
                end


            end% if not finished
        end% for every agent
        %% 
        if mod(iter,1)==0
            last_lam_d=lam_d;
%             last_lam_b=lam_b;
            last_lam_up=lam_up;
            last_lam_c=lam_c;
            last_lam_w=lam_w;
            [lam_d,lam_up,lam_c,formation_residue,dyncouple_residue,compl_residue]=update_lam(commDiGr,b,u, lam_d,lam_up,lam_c,horizonSteps);
            finished{1} = false;
            finished{2} = false;
            finished{3} = false;
            finished{4} = false;
            finished{5} = false;
            figure(20)
%             subplot(2,2,1)
            if iter>1
                set(h1,'LineWidth',0.5)
                set(h2,'LineWidth',0.5)
                set(h3,'LineWidth',0.5)
                set(h4,'LineWidth',0.5)
                set(h5,'LineWidth',0.5)
                set(h6,'LineWidth',0.5)
                set(h7,'LineWidth',0.5)
                set(h8,'LineWidth',0.5)
                set(h77,'LineWidth',0.5)
                set(h88,'LineWidth',0.5)
                
                set(h9,'LineWidth',0.5)
                set(h10,'LineWidth',0.5)
                set(h11,'LineWidth',0.5)
                set(h12,'LineWidth',0.5)
                set(h13,'LineWidth',0.5)
                set(h14,'LineWidth',0.5)
                set(h15,'LineWidth',0.5)
                set(h16,'LineWidth',0.5)
                set(h155,'LineWidth',0.5)
                set(h166,'LineWidth',0.5)
            end
            
            subplot(2,3,2)
            title('agent 2 residue')
            h1=plot(1:horizonSteps,squeeze(formation_residue(1,1,:)),'b','LineWidth',2);
            hold on
            h2=plot(1:horizonSteps,squeeze(formation_residue(1,2,:)),'k','LineWidth',2);
            subplot(2,3,3)
            title('agent 3 residue')
            h3=plot(1:horizonSteps,squeeze(formation_residue(2,1,:)),'b','LineWidth',2);
            hold on
            h4=plot(1:horizonSteps,squeeze(formation_residue(2,2,:)),'k','LineWidth',2);
            subplot(2,3,4)
            title('agent 4 residue')
            h5=plot(1:horizonSteps,squeeze(formation_residue(3,1,:)),'b','LineWidth',2);
            hold on
            h6=plot(1:horizonSteps,squeeze(formation_residue(3,2,:)),'k','LineWidth',2);
            
            subplot(2,3,1)
            title('force balance residue')
            h7=plot(1:horizonSteps-1,squeeze(dyncouple_residue(1,1,:)),'b','LineWidth',2);
            hold on
            h8=plot(1:horizonSteps-1,squeeze(dyncouple_residue(1,2,:)),'k','LineWidth',2);
            
            subplot(2,3,5)
            h77=plot(1:horizonSteps,squeeze(compl_residue(1,1,:)),'b','LineWidth',2);
            hold on
            h88=plot(1:horizonSteps,squeeze(compl_residue(1,2,:)),'k','LineWidth',2);
            
            
            figure(88)
            subplot(2,3,1)
            h9=plot(1:horizonSteps-1,squeeze(lam_up(1,1,:)),'b-','LineWidth',2);
            hold on
            h10=plot(1:horizonSteps-1,squeeze(lam_up(1,2,:)),'r-','LineWidth',2);
            title('lam_u')
            subplot(2,3,2)
            h11=plot(1:horizonSteps,squeeze(lam_d(1,1,:)),'b-','LineWidth',2);
            hold on
            h12=plot(1:horizonSteps,squeeze(lam_d(1,2,:)),'r-','LineWidth',2);
            title('lam_d1')
            subplot(2,3,3)
            h13=plot(1:horizonSteps,squeeze(lam_d(2,1,:)),'b-','LineWidth',2);
            hold on
            h14=plot(1:horizonSteps,squeeze(lam_d(2,2,:)),'r-','LineWidth',2);
            title('lam_d2')
            subplot(2,3,4)
            h15=plot(1:horizonSteps,squeeze(lam_d(3,1,:)),'b-','LineWidth',2);
            hold on
            h16=plot(1:horizonSteps,squeeze(lam_d(3,2,:)),'r-','LineWidth',2);
            title('lam_d3')
            subplot(2,3,5)
            h155=plot(1:horizonSteps,squeeze(lam_c(1,1,:)),'b-','LineWidth',2);
            hold on
            h166=plot(1:horizonSteps,squeeze(lam_c(1,2,:)),'r-','LineWidth',2);
            title('lam_w')
            figure(89)
            subplot(2,3,1)
            plot([iter-1,iter],[sum(squeeze(last_lam_up(1,1,:)),'all'),sum(squeeze(lam_up(1,1,:)),'all')],'b-*')
            hold on
            plot([iter-1,iter],[sum(squeeze(last_lam_up(1,2,:)),'all'),sum(squeeze(lam_up(1,2,:)),'all')],'r-*')
            title('lam_u')
            subplot(2,3,2)
            plot([iter-1,iter],[sum(squeeze(last_lam_d(1,1,:)),'all'),sum(squeeze(lam_d(1,1,:)),'all')],'b-*')
            hold on
            plot([iter-1,iter],[sum(squeeze(last_lam_d(1,2,:)),'all'),sum(squeeze(lam_d(1,2,:)),'all')],'r-*')
            title('lam_d1')
            subplot(2,3,3)
            plot([iter-1,iter],[sum(squeeze(last_lam_d(2,1,:)),'all'),sum(squeeze(lam_d(2,1,:)),'all')],'b-*')
            hold on
            plot([iter-1,iter],[sum(squeeze(last_lam_d(2,2,:)),'all'),sum(squeeze(lam_d(2,2,:)),'all')],'r-*')
            title('lam_d2')
            subplot(2,3,4)
            plot([iter-1,iter],[sum(squeeze(last_lam_d(3,1,:)),'all'),sum(squeeze(lam_d(3,1,:)),'all')],'b-*')
            hold on
            plot([iter-1,iter],[sum(squeeze(last_lam_d(3,2,:)),'all'),sum(squeeze(lam_d(3,2,:)),'all')],'r-*')
            title('lam_d3')
            subplot(2,3,5)
            plot([iter-1,iter],[sum(squeeze(last_lam_c(1,1,:)),'all'),sum(squeeze(lam_c(1,1,:)),'all')],'b-*')
            hold on
            plot([iter-1,iter],[sum(squeeze(last_lam_c(1,2,:)),'all'),sum(squeeze(lam_c(1,2,:)),'all')],'r-*')
            title('lam_w')
        end
        
%         lam_d(lam_d>1.0)=1.0;
%         lam_d(lam_d<-1.0)=-1.0;
        %% 
        
        
        for i = 1:size(commDiGr.Nodes,1)
        % iLQG iteration finished, take the policy to execute
            agents{i}.updatePolicy(b(i,:),u(i,:),L_opt{i});
            % guess value only used for the first iLQG iteration of each MPC iteration
            
        end
        if finished{1} && finished{2} && finished{3} && finished{4} && finished{5} && iter>5
            break;
        end
%             error_policy_3_from_1 = squeeze(u{3,1}(1,:,:)-u{1,1}(1,:,:));
%             error_policy_4_from_3 = squeeze(u{4,1}(3,:,:)-u{3,1}(3,:,:));
%             figure(3)
%             plot(error_policy_3_from_1(1,:))
%             hold on
%             plot(error_policy_3_from_1(2,:))
%             figure(4)
%             plot(error_policy_4_from_3(1,:))
%             hold on
%             plot(error_policy_4_from_3(2,:))
        
%         time_past = (i_sim-1) * mpc_update_period;
%         [~, ~, ~] = animateAdmm(commDiGr,agents, b0, x_true,update_steps,time_past, show_mode,false);

    end%iLQG iter
    total_t = toc;
    fprintf(['\n'...
        'iterations:   %-3d\n'...
        'time / iter:  %-5.0f ms\n'...
        'total time:   %-5.2f seconds\n'...
        '=========== end iLQG ===========\n'],...
        iter,1e3*total_t/iter,total_t);
    for i = 1:size(commDiGr.Nodes,1)
        u_guess(i,:) = u(i,:);
        % guess value only used for the first iLQG iteration of each MPC iteration
    end
%     if i_sim < 2
%         show_mode = REST_WISH_WITHOUT_HUMAN_INPUT;
%     else
%         show_mode = REST_WISH_WITHOUT_HUMAN_INPUT;
%     end
%     time_past = (i_sim-1) * mpc_update_period;
    assignin('base', 'interfDiGr', interfDiGr)
    assignin('base', 'commDiGr', commDiGr)
    assignin('base', 'b0', b0)
    assignin('base', 'agents', agents)
    assignin('base', 'update_steps', update_steps)
    assignin('base', 'time_past', time_past)
    assignin('base', 'show_mode', show_mode)
    assignin('base', 'x_true', x_true)
    for i = 1:size(interfDiGr.Nodes,1)
        agents{i}.ctrl_ptr = 1;
    end
    [~, b0_next, x_true_next] = animateBeliefAdmm(109,110,interfDiGr,agents, b0, x_true,update_steps,time_past, show_mode,false);
%     b0{1}(1:2) = x_true_final(1:2);
    b0 = b0_next;
    x_true = x_true_next;
end
% figure(3)
% plot(error_policy_3_from_1(1,:),'.k')
% plot(error_policy_3_from_1(2,:),'.k')
% figure(4)
% plot(error_policy_4_from_3(1,:),'.k')
% plot(error_policy_4_from_3(2,:),'.k')
end
function [lam_d_new,lam_up_new,lam_c_new,formation_residue,dyncouple_residue,compl_residue]=update_lam(D,b,u, lam_d,lam_up,lam_c,horizonSteps)
    formation_residue = zeros(3,2,horizonSteps);
%     consensus_residue = zeros(3,2,horizonSteps);
    dyncouple_residue = zeros(1,2,horizonSteps-1);
    compl_residue = zeros(1,2,horizonSteps);
    components_amount=2;
    stDim_platf = 4;
    stDim=2;
    x_platf = zeros(2,horizonSteps);
    x_goals = zeros(2,components_amount,horizonSteps);
    for k=1:horizonSteps
        [x_platf_comp, P_platf, w] = b2xPw(b{1,1}(:,k), stDim_platf, components_amount);

        x_platf_weighted = zeros(2,components_amount);
        for i=1:components_amount
            x_platf_weighted(:,i)=transpose(x_platf_comp{i}(3:4)*w(i));
        end
        x_platf(:,k)= [sum(x_platf_weighted(1,:));sum(x_platf_weighted(2,:))];
        x_goals(:,1,k)=x_platf_comp{1}(1:2);
        x_goals(:,2,k)=x_platf_comp{2}(1:2);
        compl_residue(1,:,k) = w(1)^2*(b{5,5}(1:stDim,k)-x_goals(:,2,k))...
            +w(2)^2*(b{5,5}(1:stDim,k)-x_goals(:,1,k));
    end
    for i=2:4
        edge_row = i-1;
        for k=1:horizonSteps
            w1_index = 21;
            w2_index = 42;
            formation_residue(i-1,:,k) = ...
                (b{i,i}(1:stDim,k)-x_platf(:,k)-(D.Edges.nom_formation_2(edge_row,:))')*b{1,1}(w2_index,k)^2 ...
            +(b{i,i}(1:stDim,k)-x_platf(:,k)-(D.Edges.nom_formation_1(edge_row,:))')*b{1,1}(w1_index,k)^2;
%             consensus_residue(i-1,:,k) = b{i,i}(1:stDim,k)-x_platf(:,k);
        end
    end
    for k=1:horizonSteps-1
        dyncouple_residue(1,:,k) = 3*u{1,1}(5:6,k)-u{2,2}(:,k)-u{3,3}(:,k)-u{4,4}(:,k);
    end
%     for k=1:horizonSteps
%         
%     end
    lam_d_new = lam_d + formation_residue;
%     lam_b_new = lam_b + consensus_residue;
    lam_up_new = lam_up + dyncouple_residue;
    lam_c_new = lam_c + compl_residue;
end
