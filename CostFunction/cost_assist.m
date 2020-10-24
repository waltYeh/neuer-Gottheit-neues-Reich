function c = cost_assist(D, ...
    idx, b, u, horizon, stateValidityChecker)

% one step cost, not the whole cost horizon
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Compute cost for vector of states according to cost model given in Section 6 
% of Van Den Berg et al. IJRR 2012
%
% Input:
%   b: Current belief vector
%   u: Control
%   goal: target state
%   L: Total segments
%   stDim: state space dimension for robot
%   stateValidityChecker: checks if state is in collision or not
% Outputs:
%   c: cost estimate
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

c = zeros(1,size(b,3));
% if size(b,3)>1  
% % % size is n_b * 1 * ((n_b+n_u+1)horizon) for deri before backward path
% % % size of u is n_u * 1 * ((n_b+n_u+1)horizon) with NaN at the end of
% % % horizons
%     keyboard
% end
% size is n_agent * n_b for forward path
% incoming_nbrs_idces = predecessors(D,idx);
for j=1:size(b,3)
%     if isempty(varargin)
%     b_this_for_paral = cell(size(b));
%     u_this_for_paral = cell(size(u));
%     for i = incoming_nbrs_idces
%         b_this_for_paral{i} = b{i}(:,j);
%         u_this_for_paral{i} = u{i}(:,j);
%     end
%     b_this_for_paral{idx} = b{idx}(:,j);
%     u_this_for_paral{idx} = u{idx}(:,j);
    c(j) =  evaluateCost(D, idx, squeeze(b(:,:,j)),squeeze(u(:,:,j)), horizon, stateValidityChecker);
%     else
%         c(i) =  evaluateCost(b(:,i),u(:,i), goal, stDim, L, stateValidityChecker, varargin{1});
%     end
end

end

function cost = evaluateCost(D, idx, b, u, L, stateValidityChecker)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Compute cost for a states according to cost model given in Section 6 
% of Van Den Berg et al. IJRR 2012
%
% Input:
%   b: Current belief vector 4x2
%   u: Control 4x6
%   goal: target state
%   stDim: State dimension
%   L: Number of steps in horizon
%   stateValidityChecker: checks if state is in collision or not
% Outputs:
%   c: cost estimate
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% cost = 0;
stDim = 2;
incoming_nbrs_idces = predecessors(D,idx)';

final = isnan(u(idx,1,:));
% u(:,final)  = 0;
for j = [idx, incoming_nbrs_idces]
    u(j,:,final)  = 0;
end
x_idx = transpose(b(idx,1:stDim,1));
% x_plattform = transpose(b(idx,7:8,1));
P_idx = zeros(stDim, stDim); % covariance matrix
% Extract columns of principal sqrt of covariance matrix
% right now we are not exploiting symmetry
for d = 1:stDim
    P_idx(:,d) = b(idx,d*stDim+1:(d+1)*stDim, 1);
end
% u{idx}(:,final)  = 0;
% ctrlDim = size(u{idx},1);
% collision cost
cc = 0;

% State Cost
sc = 0;

% information cost
ic = 0;

% control cost
uc = 0;
[eid,nid] = inedges(D,idx);
rij_control = 0.0;
% q_formation = 2;
rii_control = 0.1;
if any(final)
    
%     for j_nid = 1:length(nid)
%         j = nid(j_nid);
%         edge_row = eid(j_nid);
%         x = transpose(b(j,1:stDim,1));
%         P = zeros(stDim, stDim); % covariance matrix
%     % Extract columns of principal sqrt of covariance matrix
%     % right now we are not exploiting symmetry
%         for d = 1:stDim
%             P(:,d) = b(j,d*stDim+1:(d+1)*stDim, 1);
%         end
% %         RowIdx = ismember(D.Edges.EndNodes, [j,idx],'rows');
% %         formation_error = x_idx-x-(D.Edges.nom_formation_2(edge_row,:))';
% %         sc = sc + L*0.5*q_formation*(formation_error'*formation_error);
%     end
%   
else
%     for j_nid = 1:length(nid)
%         j = nid(j_nid);
%         edge_row = eid(j_nid);
%         x = transpose(b(j,1:stDim,1));
%         P = zeros(stDim, stDim); % covariance matrix
%         for d = 1:stDim
%             P(:,d) = b(j,d*stDim+1:(d+1)*stDim, 1);
%         end
%         uc = uc + 0.5*rij_control*(transpose(u(j,:))'*transpose(u(j,:)));
%         formation_error = x_idx-x-(D.Edges.nom_formation_2(edge_row,:))';
% %         sc = sc + 0.1*q_formation*(formation_error'*formation_error);
%         
%         
% 
%         %sigmaToCollide(b,stDim,stateValidityChecker);
%         
%     end
%     nSigma = sigmaToCollide_multiagent_D(D,idx,b,2,stateValidityChecker);
%     for j=incoming_nbrs_idces
%         cc = cc-log(chi2cdf(nSigma(j)^2, stDim));
%     end
    uc = uc + rii_control*(transpose(u(idx,:))'*transpose(u(idx,:)));
end
edge_row = idx-1;
% formation_error = (x_idx-x_plattform-(formation_table1(edge_row,:))');%*w(2)^2 ...

%+(x_idx-x_platf-(D.Edges.nom_formation_1(edge_row,:))')*w(1)^2;
Q_form=1*eye(2);
% sc=sc+formation_error'*Q_form*formation_error;
w_cc = 1.0;
cost = sc + ic + uc + w_cc*cc;

end
