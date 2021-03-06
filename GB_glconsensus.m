function GB_glconsensus(adjmatpath,outpath,varargin)

% fprintf('1')
% GB_GLCONSENSUS Consensus community detection using the Louvain-like
% modularity-maximisation procedure, as implemented in genlouvain.m
%
% GB_glconsensus reads in a path to either:
%   (1) a square symmetric adjacency matrix
%   (2) an array containing timeseries of edges in columns
%
% GB_glconsensus repeats genlouvain-based clustering nreps times per agreement
% cycle until convergence. The resultant partition is defined as the consensus partition
%
%
% REQUIRES: 
% genlouvain.m (http://netwiki.amath.unc.edu/GenLouvain/GenLouvain) 

% Define defaults
nreps = 100;
gamma = 1;
omega = 0;
consensus = 0;
T=1;

% Print output path
outpath

% Print adjacency matrix path
adjmatpath

load(adjmatpath);
A = connectivity;

% Set the number of repetitions
for i=1:2:length(varargin)
    switch varargin{i}
        case 'nreps'
            nreps = varargin{i+1};
        case 'gamma'
            gamma = varargin{i+1};
        case 'omega'
            omega = varargin{i+1};
        otherwise
            warning(['Unknown option: ' varargin{i} '\n'])
    end
end

% Determine whether the input is an adjacency matrix or an edge timeseries
% if issymmetric(A)
%   adjmat = 1;
N = size(A,1);
T = 1;
adjmat = A;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Original Rastko Consensus Approach %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
preagreement = zeros(N,nreps);
for r = 1:nreps
        % Prepare a pre-agreement matrix
        % Allocate memory for a sparse matrix based on the input adjacency matrix
        % or edge timeseries
        % This is more generalisable but slower for the case of a single-slice
        % matrix
        B=spalloc(N*T,N*T,N*N*T+2*N*T);
        % Convert the adjacency matrix to a modularity matrix
        twomu=0;
        for s=1:T
            k=sum(A(:,:,s));
            twom=sum(k);
            twomu=twomu+twom;
            indx=[1:N]+(s-1)*N;
            B(indx,indx)=A(:,:,s)-gamma*k'*k/twom;
        end
        S = genlouvain(B,10000,0);
        S = reshape(S,[N,1]);
        % Write it into the pre-agreement matrix
        preagreement(:,r) = S;
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Repeat modularity maximization until the agreement matrix becomes binary (convergence) %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

while consensus ~= 1
    % Iterate for nreps
    preagreement = zeros(N,T,nreps);
    agreement = zeros(N,N,T,nreps);
    for r = 1:nreps
        % Prepare a pre-agreement matrix
        % Allocate memory for a sparse matrix based on the input adjacency matrix
        % or edge timeseries
        % This is more generalisable but slower for the case of a single-slice
        % matrix
        B=spalloc(N*T,N*T,N*N*T+2*N*T);
        % Convert the adjacency matrix to a modularity matrix
        twomu=0;
        for s=1:T
            k=sum(A(:,:,s));
            twom=sum(k);
            twomu=twomu+twom;
            indx=[1:N]+(s-1)*N;
            B(indx,indx)=A(:,:,s)-gamma*k'*k/twom;
        end
        twomu=twomu+2*omega*N*(T-1);
        B = B + omega*spdiags(ones(N*T,2),[-N,N],N*T,N*T);
        S = genlouvain(B,10000,0);
        S = reshape(S,[N,T,1]);
        % Write it into the pre-agreement matrix
        preagreement(:,:,r) = S;
        % Convert pre-agreement vector to agreement matrix
        for s=1:T
            agreement(:,:,s,r) = bsxfun(@eq,preagreement(:,s,r),preagreement(:,s,r)');
        end
    end
    agreement = mean(agreement,4);
    A = agreement;

    % Determine whether consensus has been reached: if it has, the
    % sampled solution space will be deterministic, so only binary values
    % will exist in the agreement matrix
    if isempty(setdiff(unique(agreement),[0,1]))
        consensus = 1;
    end

end

% Compute modularity for the consensus partition
twomu = 0;
for s=1:T
    k=sum(adjmat(:,:,s));
    twom=sum(k);
    twomu=twomu+twom;
    indx=[1:N]+(s-1)*N;
    B(indx,indx)=adjmat(:,:,s)-gamma*k'*k/twom;
end

Q = sum(B(bsxfun(@eq,S,S.'))) ./ twomu;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Write out consensus community affilitiation vector and associated Q value %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
dlmwrite([outpath '_community.1D'],S,'delimiter',' ');
dlmwrite([outpath '_quality.txt'],full(Q),'delimiter',' ');

end
