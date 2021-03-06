classdef SpikeBanhoff < Viewer
% =========================================================================
% SpikeBanhoff (<a href="matlab:edit('SpikeBanhoff')">Edit</a>)
% 
% This object contains all the spiking data for a given experiment.  This
% data is stored in property T, a cell array of size {nCells,nTrials}.  The
% class has a whole bunch of methods for doing various sorts of spiketrain
% analysis.  
%
% It loads the data from the raw files using the <a href="matlab:help('FileCat')">FileCat</a> object.
% 
% % See <a href="matlab:help('ScriptoCats')">ScriptoCats</a> for how this class fits in to the big picture. 
%
% =========================================================================    
    
    %% Idea
    % SpikeBanhoff should be a central place where spiketrain data and LFP
    % can all be brought together, correlated and compared, etc.  It's a
    % little tricky, cause there're a bunch of different signals from
    % different sources (ie-spikes, LFP, fake spikes that you make with
    % poisson processes) 
    %
    % Plotting Methods:
    % Look at the green text below all the Plot_* methods
    
    
    
    properties (SetObservable)
        %% Settings:
        resolution=0.001;   % Default to 1ms resolution 
        
        
        sWidth=0.05;         % Width of smoothing kernel (seconds)
        sType='sumbin';     % Type of smoothing kernel ('bin','gauss')
        
        
        %% Data
        
                
        
        T={};               % Array of spike trains (nNeurons x nTrials)
        
        
        description;        % 
        ids;                % ID-tags of the neurons.
        
        cond;               % Vector of trials
        
        LFP;                % LFP data
        
        % Smoothing Related
        
        P=PairComp;         % See function, it's pretty cool, good for pairwise comparisons of signals
        
        name;
        
        FC;                 % FileCat Object: Gives access to all the nasty stuff
        
        
    end
    
    properties (Transient, SetObservable)
        TS;                 % Timeseries matrix.. (nSamples x nTrials x nNeurons)
        sTS;                % Smoothed timeseries
        isi;                % Matrix of isis
        
        starttime;          % time of TS(1)
        endtime;            % time of TS(end)
        
    end
    
    methods % User Interface
        %%
                
        function StartUp(A)
            
           a=methods(A);
           a=a(cellfun(@(x)~isempty(strfind(x,'Plot_')),a));
            
%            A.menu4(A.name,['GrabCat';a]);
            
        end
                
        function GrabCat(A,C,removeBadCells,removeCell0)
            % C should be a FileCat Object.  Leave it blank to just fine
            % it.
            
            if ~exist('removeBadCells','var'), removeBadCells=false; end
            if ~exist('removeCell0','var'), removeCell0=true; end
            
            if ~exist('C','var')
                F=FelineFileFinder; 
                F.Start;
                C=F.GrabCat;
            end
            
            % Load psth's, remove zero-labelled spikes
            [T_,cond_,ids_]=C.PSTH(removeBadCells);            
            if length(cond_)~=size(T_,2) % Check
                error(['The length of your condition matrix is not equal '...
                    'to the number of trials.  Something''s wrong in FileCat.']);
            end           
            
            % Remove "zero class" trials - these are unclassified neurons.
            if removeCell0
                T_=T_(ids_~=0,:);
                ids_=ids_(ids_~=0);
            end
            
            % Load into Object
            A.FC=C;
            A.name=C.catName;
            A.T=T_;
            A.cond=cond_;
            A.ids=ids_;

            
        end
        
        function UI_Load_Files(A)
%             [fspike fsync]=fileloadGUI;
                        


            F=FileCat; 
            F.GetFiles;
            [spikes id bound condish]=F.loadSpikeInfo;
            
            A.name=sprintf('Cat%s %s %s',F.cat,F.stage,F.type);
            
            if isnumeric(spikes)
                A.T=SplitSpikes(spikes,id,bound);
                A.cond=condish;
            elseif iscell(spikes)
                A.T=spikes;
                A.cond=condish;
            end
            
            
            
            
        end
        
        function Load_File(A,file)
            
            if exist('file','var') && ~exist(file,'file')
                fprintf('File: "%s"\ndoesn''t exist!  Get another.\n',file)
                clear file;
            end
            
            
            if ~exist('file','var')                                
                [file path]=uigetfile;
                file=[path file];
            end
            
            F=load(file);
            
            
            
            if ~isfield(F,'cluster_class');
                A.Train_Factory(cluster_class);
            elseif isfield(F,'psths')
                A.T=psths;
            end
                        
        end
        
        
    end
    
    methods % Functions that modify the object
        %%
        
        function Poisson_Factory(A,ix,rate,time)
            
            for i=ix
                A.T{i}=PoissonTrain(rate,time);
            end
        end
                       
        function addLFP(A,signal,samplerate)
            
            fprintf ('Signal will be resampled to resolution of %gS/s to match the spiketrain data\n',1/A.resolution);
            
            
        end % Unused Now
        
        function AddTrain(A)
           N=length(A.T)+1;
           
           
            
            
        end % Unused Now
        
        function cropTimes(A,window)
            % Cut the trial times so that only events in the specified
            % winow are kept.  If window is a scalar it will be assumed to
            % start at 0.
            
            if numel(window)==1
                window=[0 window];
            end
            
            window=sort(window);
            
            A.T=cellfun(@(x)x(x>window(1) & x<window(2)),A.T,'uniformoutput',false);
                        
        end
        
        function takeMaxCell(A)
            % Take just the most active cell, remove the others.
            
            activity=A.nS;
            
            [~,ix]=max(sum(activity,2));
            
            A.T=A.T(ix,:);
            
        end
        
    end
    
    methods % Get/Set Functions and Dependency Control, and related
        %%
        
        function Dependencies(A,src)
            % Setup parent/child dependencies
            switch src.Name
                case 'T'
                    A.TS=[];
                    A.isi=[];
                    A.starttime=[];
                    A.endtime=[];
                case {'resolution' 'endtime'};
                    A.TS=[];
                case {'TS' 'sWidth' 'sType'}
                    A.sTS=[];
            end
        end
                
        function cond=get.cond(A)
            
            if isempty(A.cond)
                disp '"cond" should be manually set.  For now, we''ll give you all the same condition.' 
                cond=ones(1,size(A.T,2));
            else
                cond=A.cond;
            end
            
        end
                
        function sTS=get.sTS(A)
            if isempty(A.sTS)       
                fprintf('Hold on... Smoothing...');
                A.sTS=A.SmoothSeries(A.sWidth,A.sType);
                disp Done.
            end
            sTS=A.sTS;
        end
        
        function sWidth=get.sWidth(A)
            if isempty(A.sWidth)
%                 A.sWidth=input('Enter Kernel Width!: ');
                disp 'Need a kernel width to calculate sTS';
            end
            sWidth=A.sWidth;
            
        end
        
        function isi=get.isi(A)
            if isempty(A.isi)
                A.isi=cellfun(@diff,A.T,'UniformOutput',false);
            end
            isi=A.isi;
        end
        
        function endtime=get.endtime(A)
            if isempty(A.endtime)
                A.startend;
            end
            endtime=A.endtime;            
        end
        
        function starttime=get.starttime(A)
            if isempty(A.endtime)
                A.startend;
            end
            starttime=A.starttime;            
        end
        
        function TS=get.TS(A)
            % size: (nSamples x nTrials x nNeurons)
            
            if isempty(A.TS)
                                
                TS=false(ceil((A.endtime-A.starttime)/A.resolution),size(A.T,3),size(A.T,1));
                for i=1:size(A.T,2) % Trial Counter
                    for j=1:size(A.T,1) % Neuron Counter
                        ix=floor((A.T{j,i}-A.starttime)./A.resolution)+1;
                        TS(ix,i,j)=true;   
                    end
                end
                A.TS=TS;
                
            else
                TS=A.TS;
            end
            
        end
        
        function startend(A)
            validix=cellfun(@(x)~isempty(x),A.T);
            A.starttime=    min( cellfun(@(x) x(1)   , A.T(validix)));
            A.endtime=      max( cellfun(@(x) x(end) , A.T(validix)));
        end
        
    end
            
    methods % Analysis - Generally Useful
        %%
        
        function cT=condTrainArray(A)
            % Return a cell array of spike times, size
            % {nCells, nCond, nMinTrialsPerCond}
            
            C=A.condTrials;
            
            len=cellfun(@length,C);
            mL=min(len);
            
            cT=cell(size(A.T,1),length(C),mL);
            for i=1:length(C)
                cT(:,i,:)=reshape(A.T(:,C{i}(1:mL),:),size(A.T,1),1,mL); 
            end
            
        end
        
        
        function tss=SmoothSeries(A,smoothw,kernelType)
           % Smooth
            if ~exist('kernelType','var'), kernelType='gauss'; end % 1ms bins
            
            
            kern=A.kernel(smoothw,kernelType);
            
%             tss=conv(double(A.TS),kern,'same');    
            tss=convn(double(A.TS),kern,'same');   % Should be the same 
            
%             tss=fastconv(double(A.TS),kern);
            
        end
                
        function kern=kernel(A,smoothw,kernelType)
            if isempty(smoothw)
                error('The smoothing kernel width is empty.  What are you doing?')
            end
            
            
            switch kernelType
                case 'gauss' % sWidth specifies width at half-height
                   edge=ceil(1.8*smoothw/A.resolution);
                   t=-edge:edge;
                   vari=(smoothw/A.resolution/sqrt(log(256)))^2;
                   kern=1/(sqrt(2*pi)*vari)*exp(-t.^2/(2*vari))'; 
                case 'meanbin' % sWidth specifies window size
                   edge=ceil(0.5*smoothw/A.resolution);
                   t=-edge:edge;
                   kern=repmat(1/length(t),size(t))';
                case 'sumbin' % sWidth specifies window size
                   edge=ceil(0.5*smoothw/A.resolution);
                   t=-edge:edge;
                   kern=ones(size(t))';
                otherwise
                    error('Unknown kernel type "%s"',kernelType);
                   
            end
            
        end
                
        function nS=nS(A) % Number of spikes for each neuron in each trial
            nS=cellfun(@length,A.T);
        end
        
        function nN=nN(A) % Number of neurons
           nN=size(A.T,1); 
        end
        
        function nT=nT(A) % Number of trials
            nT=size(A.T,2);
        end
        
        function Tc=condTrains(A)
           % Combine all spikes by condition to form a new cell array
           % {nCells,nCond}.
           
           [C u]=A.condTrials;
                      
           Tc=cell(A.nN,length(C));
           for i=1:A.nN
               for j=1:length(C)
                   Tc{i,j}=sort(cat(1,A.T{i,C{j}}));
               end
           end
           
        end
        
        function dist=isidist(A,upperlim)
            % List of isi's for each cell, concatenated over trials
                
            
            dist=cell(A.nN,1);
            for i=1:A.nN
                dist{i}=cell2mat(A.isi(i,:)');
            end
            
            % If upperlim specified, cut out isis above it.
            if exist('upperlim','var'),
                dist=cellfun(@(x)x(x<upperlim),dist,'uniformoutput',false);
            end
            
            
        end
        
        function dist=CVdist(A,upperlim)
            % List of cv's for each cell, concatenated over trials.
            % Consider only CV's associated with isi-times below upperlim
                
            
            isidist=A.isiPairs;
            
            if exist('upperlim','var'), 
               isidist=cellfun(@(x)x(:,all(x<upperlim)),isidist,'uniformoutput',false);
            end
            
            dist=cellfun(@(x)2*abs(diff(x))./sum(x),isidist,'uniformoutput',false);
            
%             
%             dist=cell(A.nN,1);
% %             cv2=cellfun(@(X)2*abs(X(2:end)-X(1:end-1))./(X(1:end-1)+X(2:end)),A.isi,'uniformoutput',false);
%             
%             diffs=cellfun(@(X)2*abs(X(2:end)-X(1:end-1)),A.isi,'uniformoutput',false);
%             sums=cellfun(@(X)X(1:end-1)+X(2:end),A.isi,'uniformoutput',false);
%             
%             % If upperlim specified, cut out isis above it.
%             if exist('upperlim','var'),
%                 valid=cellfun(@(s)s<upperlim*2,sums,'uniformoutput',false); % Where the two don't on average exceed upperlim
%                 sums=cellfun(@(s,v)s(v),sums,valid,'uniformoutput',false);
%                 diffs=cellfun(@(s,v)s(v),diffs,valid,'uniformoutput',false);
%             end
%             
%             error('This method is flawed: It couts out invalid isi''s before taking CVs');
%             
%             cv2=cellfun(@(d,s)d./s,diffs,sums,'uniformoutput',false);
%             
%             for i=1:A.nN
%                 dist{i}=cell2mat(cv2(i,~cellfun(@isempty,cv2(i,:)))');
%             end
            
            
            
            
        end
                        
        function [FF n]=FanoFactor(A)
            
            % condStats returns the condition-wise stats for spike counts
            [means stds n]=A.condStats;
            FF=stds.^2./means;
            
        end
        
        function [FF n]=FatFanoFactor(A,twin)
           % The difference here is that the FF is calculated using the
           % the summed spike counts for repetitions of every stimulus.
           
%            [u,~,n]=unique(A.cond);
%            [~,ix]=unique(sort(n));
%            count=diff([0 ix]);
           
           if ~exist('twin','var'), twinrex=false; else twinrex=true; end

           % Get spike counts by condition
           counts=A.condCount; 
           
           % Get min number of repetitions
           n=min(cellfun(@(x)size(x,2),counts));
           
           totalcount=nan(A.nN,n);
           for i=1:n
                totalcount(:,i)=sum(cell2mat(cellfun(@(x)x(:,i),counts,'uniformoutput',false)),2);
           end
               
%            clist=A.cond;
%            totalcount=nan(A.nN,n);
%            nSpikes=A.nS;
%            for i=1:n
%                [~,loc]=ismember(u,fliplr(clist));
%                loc=length(clist)-loc+1;
%                totalcount(:,i)=sum(nSpikes(:,loc),2);
%                clist(loc)=nan;               
%            end
            
           FF=var(totalcount,[],2)./mean(totalcount,2);
        end
        
        function CV=CV(A)
            CV=cellfun(@(x)std(x)/mean(x),A.isi);            
        end
        
        function CV2=CV2median(A)
            % Return the modified coefficient of varianstion.  Basically,
            % median([isi(i),isi(i+1)])
            
            
            p=A.isiPairs;            
            
            CV2=cellfun(@(x)2*median(abs(diff(x))./sum(x)),p);
            
            
%             CV2=cellfun(@(X)2*median(abs(X(2:end)-X(1:end-1))./(X(1:end-1)+X(2:end))),A.isi);
        end
                      
        function [means stds ns]=condStats(A)
            % Returns means std's n's of spike counts by condition.
                        
            count=A.condCount; %(1 x conditions) array containing spike counts by (neuron,trial)
            means=cell2mat(cellfun(@(x)mean(x,2),               count,'uniformoutput',false));
            if nargout>1
                stds=cell2mat(cellfun(@(x)std(x,[],2),              count,'uniformoutput',false));
                if nargout>2
                    ns=cell2mat(cellfun(@(x)size(x,2),                  count,'uniformoutput',false));
                end
            end
        end
        
        function [FF mn vr]=FanoSmooth(A)
           % Takes the FF of the sTS signal, optionally returning the mean
           % too.
           % Also.. returns the origninal smoothing type.
           
           oldtype=A.sType;
           smooth=A.sTS;
           
           if ~strcmp(oldtype,'sumbin'),
               A.sType='sumbin';
           end
           
           mn=squeezecond(A.sTS,2,A.cond,'mean');
           vr=squeezecond(A.sTS,2,A.cond,'var');
           
           FF=vr./mn;
           
           % Return to old params
           A.sType=oldtype;
           A.sTS=smooth;
            
            
        end
        
        function drft=DriftTest(A,normalize)
            % drft is a nRepititions x nConditions matrix, where
            % nRepetitions is the number of repepetitions of the
            % most-repeated condition, nConditions is the number of
            % conditions.  It contains the spike counts.  The idea is to
            % test if there is a "drift" over the course of the experiment.
            % If you set normalize to true, all the matrix will be divided
            % by the first row.
            
            
        end
        
        function R=trialCorrMat(A)
            % Returns matrix of correlations between the smoothed signals,
            % by trial.  eg. R(i,j,k) is the correlation between the signal
            % from trials i and trial j, for neuron k.  Note that this
            % depends on yout current smoothing settings (sWidth and sType)
                                    
            R=nan(size(A.sTS,2),size(A.sTS,2),size(A.sTS,3));
            
            ssTS=A.sTS;
            for i=1:size(A.sTS,3)
               R(:,:,i)=corrcoef(ssTS(:,:,i)); 
            end
            
            R(isnan(R))=0; % Define limit case
            
        end
                
        
    end
    
    methods % Analysis - A bit specific
        %%       
        
        function rate=meanSpikeRate(A)
            % Returns the average rate of spiking per neuron, over all
            % trials.
            
            rate=mean(A.nS,2)./diff([A.starttime,A.endtime]);
            
            
            
        end
            
        function D=Drivenness(A,R)
            % D is a vector indicating difference between the mean
            % intra-trial correlation and mean extra-trial correlation for
            % each trial.  It's size is (nTrials x nNeurons).  D is always
            % positive.  Near-zero values indicate no seperability between
            % intra/inter trial, near-1 indicates that the square
            % difference in means equals the sum of variances (borderline
            % significant).  Higher values indicate that the cell is
            % significantly driven. Naturally, it's important to check your
            % N.
            %
            % R is an optional time-saving input of the trialCorrMat.  If
            % you don't input it will just be calculated.
            
            % This code is implemented at best half as efficiently as it
            % could be but I don't really care.
            
            if ~exist('R','var')
                R=A.trialCorrMat;
            end
            
            C=A.condTrials; % Cell array of trials for each condition
            
            D=nan(length(C),A.nN);
            for i=1:size(D,1);    
                for j=1:size(D,2)
                    ixin=C{i};
                    ixout=cell2mat(C(1:length(C) ~= i));
                    
                    % Matrix within condition group
                    inmat=R(ixin,ixin,j); 
                    sin=size(inmat); inmat(sub2ind(sin,1:sin(1),1:sin(1)))=[];  % Remove Self-correlation
                    
                    % Matrix between condition groups
                    outmat=R(ixin,ixout,j);
                    
                    D(i,j)=(mean(inmat(:))-mean(outmat(:)))^2/(var(inmat(:))+var(outmat(:)));
                    
                end
            end
            
            
            
        end
        
        function [sig noise intertrial noiseSE intertrialSE lags X]=SNcorr(A,n1,n2,maxlags)
            % The signal corr is the cross-correlation between neurons of
            %   the mean over trials of a certain condition
            % The noise corr is the mean over trials of a certain condition
            %   of the cross-correlation over neurons.
            % The intertrial corr is the mean cross correlation between
            %   neurons in different trials in a condition
            
            if ~exist('maxlags','var'), maxlags=floor(size(A.sTS,1)/2); end
            
            
            % Get signal corr
            [M ucond]=squeezecond(A.sTS,2,A.cond,@mean);
            sig=nan(2*maxlags+1,length(ucond));
            for i=1:length(ucond)
                if maxlags==0
                    c=corrcoef(M(:,i,n1),M(:,i,n2));
                    sig(i)=c(1,2);
                else
                    sig(:,i)=xcov(M(:,i,n1),M(:,i,n2),maxlags,'coeff');
                end
            end
            sig(isnan(sig))=0;
            
            
            C=A.condTrials;
            
            % Get Noise-corr
            X=nan(2*maxlags+1,length(A.cond));
            [X(:,1) lags]=xcov(A.sTS(:,1,n1),A.sTS(:,1,n2),maxlags,'coeff'); 
            lags=lags*A.resolution;
            for i=2:length(A.cond)
                if maxlags==0 % just saves time
                    c=corrcoef(A.sTS(:,i,n1),A.sTS(:,i,n2));
                    X(i)=c(1,2);
                else
                    X(:,i)=xcov(A.sTS(:,i,n1),A.sTS(:,i,n2),maxlags,'coeff'); 
            
                end
            end
            X(isnan(X))=0;
            noise=squeezecond(X,2,A.cond,@mean);
            noiseSE=bsxfun(@rdivide,squeezecond(X,2,A.cond,'std'),sqrt(cellfun(@length,C))); 
            
            
            % Get mean inter-trial corr.
            % Get signal corr
%             [M ucond]=squeezecond(A.sTS,2,A.cond,@mean);
            [intertrial intertrialSE]=deal(nan(size(X,1),length(ucond)));
            
            for i=1:length(ucond)
                p=pairs(C{i});
                ctemp=nan(size(X,1),size(p,1));
                for j=1:size(p,1)
                    if maxlags==0
                        c=corrcoef(A.sTS(:,p(j,1),n1),A.sTS(:,p(j,2),n2));
                        ctemp(j)=c(1,2);
                    else
                        ctemp(:,j)=xcov(A.sTS(:,p(1,j),n1),A.sTS(:,p(2,j),n2),maxlags,'coeff');
                    end        
                end
                ctemp(isnan(ctemp))=0;
                intertrial(:,i)=mean(ctemp,2);
                intertrialSE(:,i)=std(ctemp,[],2)/size(ctemp,2);
            end
                       
            function p=pairs(v)
                % Return all combinations of pairs of elements from vec v
                [p1 p2]=meshgrid(v(:));
                ix=find(p2>p1);
                p=[p1(ix) p2(ix)];               
                
            end
            
            
        end
        
        
        function ct=intraTrialCorr(A)
           % Return a nCond-length vector of the within-trial correlations.
           
           C=A.condTrials; % Cell array of trials for each condition
           
           
           R=A.trialCorrMat;
           
           ct=nan(1,length(C));
           for i=1:length(C)
               ct(i)=mean(mean(R(C{i},C{i}),2),1);
           end
            
        end
                
        function B=Poissonification(A,order)
            % Generate new poisson spike trains based on smoothed versions
            % of the old ones.  Make sure your settings for properties
            % sWidth and sType (smoothing properties) are as you want them
            % to be, because these define how the new spike train is
            % generated.
            
            if ~exist('order','var'), order=1; end
            
            if ~ismember(A.sType,{'meanbin','gauss'});
                disp 'We changed smoothing type to meanbin.';
                A.sType='meanbin';
            end
            
            A.sTS=[];
            
            profile=squeezecond(A.sTS,2,A.cond,@mean);
            
            % n relates trial # to index of condition #.  For now,
            % n=A.cond, but this may change for lettered conditions.
            [~,~,n]=unique(A.cond);
            
            bT=cell(size(A.T));
            for i=1:A.nN
                for j=1:A.nT
                    bT{i,j}=PechePourPoisson(profile(:,n(j),i)/A.resolution,A.resolution,order)+A.starttime;
                end
            end
            
            % Make a fake
            B=eval(class(A));
            B.T=bT;
            B.cond=A.cond;
            B.sWidth=A.sWidth;
            B.name=['Possonified-' A.name];
            
        end
           
        function [p t]=isiPairs(A,gap)
            % Return pairs of ISIs, separated by "gap".  They'll be
            % returned in a cell array {nCells} (nPairs, 2) .
            
            if ~exist('gap','var'), gap=1; end
            
            isis=A.isi;
            
            p=cell(1,A.nN);
            for i=1:length(p)
                valids=cellfun(@(x)length(x)>gap,isis(i,:));
                first=cell2mat(cellfun(@(x)x(1:end-gap)' ,isis(i,valids) ,'uniformoutput',false));
                second=cell2mat(cellfun(@(x)x(gap+1:end)' ,isis(i,valids) ,'uniformoutput',false));
                p{i}=[first;second];
            end
            
            
        end
        
        function [MI bins n]=ISI_MI(A,N,gap)
            % Ratio of mutual information between adjascent ISIs, and
            % shuffled MI
            % Note that in order to measure this, ISI's must be binned. 
            % n defines the number of bins to use.  
            % 
            % MI is a vector, with one element per neuron, that tells
            
            if ~exist('gap','var'), gap=1; end
            
            isis=A.isi;
            
            nShuffles=5;
%             function c=counts(v)
%                 vs=sort(v);
%                 d=find(diff(vs));
%                 c=diff([0 d length(v)]);
%             end
                
            isibinned=cell(size(A.isi));
            bins=cell(size(A.nN));
            MI=nan(A.nN,length(gap));
            n=nan(A.nN,length(gap));
            for i=1:A.nN
                isicat=cat(1,isis{i,:});
                
                if isempty(isicat)
                    fprintf('Warning: No ISI''s exist for cell %g, experiment "%s"\n',A.ids(i),A.name);
                    MI(i,:)=nan;
                    n(i,:)=0;
                    bins{i}=[];
                    continue;
                end                
                
                
                [bins{i},~,binner]=equibin(isicat,N);
                
%                 p=counts(bins)/length(bins);
                
                                
                isibinned(i,:)=cellfun(binner,isis(i,:),'uniformoutput',false);
                
                
                for j=1:length(gap)
                    valids=cellfun(@(x)length(x)>gap(j),isibinned(i,:));
                    first=cell2mat(cellfun(@(x)x(1:end-gap(j))' ,isibinned(i,valids) ,'uniformoutput',false));
                    second=cell2mat(cellfun(@(x)x(gap(j)+1:end)'  ,isibinned(i,valids) ,'uniformoutput',false));

                    MI(i,j)=MutualInformation(first,second);
                    
                    shuffs=nan(1,nShuffles);
                    for k=1:nShuffles
                        shuffs(k)=MutualInformation(first,second(randperm(length(second))));
                    end
                    MI(i,j)=MI(i,j)/mean(shuffs);
                    
                    
                    n(i,j)=length(first);
                end
                
            end
            
            
            
            
            
        end
       
        function kurt=isi_kurtosis(A,n)
           % Return kurtosis of isi's.  n is the number of subsamples to
           % take (because kurtosis measurements are often highly dependent
           % on specific samples.  
           
           isis=cell2mat(A.isi(:));
           
           if exist('n','var');
               samp=randss(isis,[length(isis) n]);
           else
               samp=isis;               
           end
            
           kurt=kurtosis(samp);
               
        end
        
        function per=periodicity(A,conditionwise)
            % Measures periodicity of each trial, defined as the ratio of
            % the max fourier coefficient to the mean.
            %
            % p will be a nNeurons x nTrials array.
            % f will be the 
            
            if ~exist('conditionwise','var'), conditionwise=true; end
            
%             if ~conditionwise
%                 trains=A.sTS;
%             else
%                 trains=squeezecond(A.TS,2,A.cond,@sum);
%             end
               
            % Area under autocorrelation method.  boo
%             per=nan(size(trains,2),A.nN);
%             for i=1:size(trains,2)*A.nN
%                  xc=(xcov(trains(:,i),'coef'));
%                  ov=xc<0;
%                  ix=[find(ov(1:fix(end/2)),1,'last'),fix(size(ov,1)/2)+find(ov(ceil(end/2):end),1)];
%                  if isempty(ix),per(i)=0; 
%                  else per(i)=mean((xc([1:ix(1), ix(2):end])).^2);
%                  end
%             end
            
            % MSE method
            
            SF=load(A.FC.stimFile);
            
            [u,m,~]=unique(A.cond);
            
            trains=A.condTrains;
            strains=squeezecond(A.sTS,2,A.cond,@sum);
            pdf=@(x,f,p)(x>=min(x) & x<=max(x)).*(sin(f*x+p)+1)/((cos(f*max(x)+p)-cos(f*min(x)+p))/f+max(x)-min(x));
            per=nan(size(trains));
            fprintf('Calculating periodicities on cat %s...',A.name);
            for i=1:numel(trains);     
                if length(trains{i})<2, per(i)=nan; continue; end
                stimfreq=SF.stimuli(m(i)).TempFreq*2*pi;
                pdfi=@(x,p)pdf(x,stimfreq,p);
                pa=mle(trains{i},'pdf',pdfi,'start',0); % HARDCODING HERE!
%                 per(i)=geomean(pdfi(trains{i},pa));
                
                c=corrcoef(strains(:,i),pdfi(A.timeVec,pa));
                per(i)=c(1,2);
            end
            disp Done
            
%             coef=abs(fft(trains));
%             coef=coef(2:ceil(end/2),:,:); % down with DC!
%             
%             [p loc]=max(coef);
%             
%             p=p./mean(coef);
%             
%             p(isnan(p))=0;
%             
%             p=permute(p,[3 2 1]);
%             
%             f=loc./(A.endtime-A.starttime);
%             
%             f=permute(f,[3 2 1]);
            
        end
        
        function [mn,sd,se]=activityTrend(A)
            % Returns a cell array of vectors, where each vector
            % corresponds to a condition, each element corresponds to the
            % number of spikes in a trial.
            
            n=A.nS;
            ac=cellfun(@(ix)n(ix),A.condTrials,'uniformoutput',false);
            
            slopes=nan(1,length(ac));
            for i=1:length(ac)
                [~,slopes(i),~]=regression(1:length(ac{i}),ac{i});
            end
            
            mn=mean(slopes);
            sd=std(slopes);
            se=sd./cellfun(@length,ac);
            
        end
        
        function [v m]=spikeCounts(A,win)
            
            [f v m]=RovingFanos(S.T,win,S.cond);
            
        end
        
        function varargout=flexicalc(A,varargin)
            % For making code on the spot.  Allows you get get around this
            % annoying need to clear memory whenever you want to change
            % input parameters.
        
        end
            
    end
    
    methods % Shortcuts and analysis helpers
        %%
        
        function [counts u]=condCount(A)
           % Returns a cell array (indexed by condition #) of vectors,
           % where counts{i}(j,k) reperesents the number of spikes from the 
           % jth neuron on the kth trial in which condition i is presented.
           
           numSpike=A.nS;
           
           [C u]=A.condTrials;
           
           counts=cellfun(@(x)numSpike(:,x),C,'uniformoutput',false);
           
                      
        end
        
        function [C u]=condTrials(A)
            % Returns a cell array of trial numbers for each condition.
            % C{i} is the vector of trial indeces for condition i.
            
            % Yes this could be vectorized, but not worth the mental effort
            u=unique(A.cond);
            C=cell(1,length(u));
            for i=1:length(u)
                C{i}=find(A.cond==u(i));               
            end
            
        end
        
        function time=timeVec(A)
            
            if isempty(A.TS), time=[];
            else time=linspace(0,A.endtime,size(A.TS,1));
            end
            
        end
        
        function v=cellISI(A)
            % Just concatenates all the isi's from each cell into a single
            % vector
            
            nC=A.nN;
            v=cell(1,nC);
            for i=1:nC
               v{i}=cell2mat(A.isi(i,:)'); 
            end
            
        end
        
    end
        
    methods % Plotting        
        %%
        
        
        function Plot_NeuronCorr(A)
            % Plot the signal, immediate, and stimulus-driven correlations
            % between the first 2 neurons.
            % 
            % Signal Correlation : Corr of mean over trials in condition
            % Immediate Correlation: Mean correlation between concurrent
            %   trials in condition.
            % Stimulus-Driven Correlation: Mean of correlation between
            %   non-concurrent trials in condition.
            %
            % For data: use function 
            % [sig imm drv immSE drvSE]=A.SNcorr(A.ids(1),A.ids(2),0);
            
            if length(A.ids)<2
                errordlg('This function requires at least 2 cells to run');
                return;
            end
            
            figure;
            
            
            A.addHelpButton;
            A.exportButton(A,'S');
            
            U=UIlibrary;
            
            [h val]=U.buttons({{'full','weighted-mean','unweighted mean'}});
            set(h(1),'callback',@(e,s)replot);
            
            replot;
            
            function replot
            
                title 'HOLD ON... COMPUTING'
                [sig imm drv immSE drvSE]=A.SNcorr(A.ids(1),A.ids(2),0);
                sigSE=zeros(size(sig));
                
                switch val{1}()
                    case 'full'
                        barweb([sig; imm; drv]',[sigSE;immSE;drvSE]');
                        xlabel 'Condition'
                        compress=false;
                    case 'mean'
                        w=[];
                        compress=true;
                    case 'weighted-mean'
                        nnS=A.nS;
                        w=cellfun(@(ix)sum(geomean(nnS(:,ix))),A.condTrials);
                        w=w/sum(w);
                        compress=true;
                        
                end
                if compress
                    sig=varcomb(sig,[],w);
                    [imm immSE]=varcomb(imm,immSE,w);
                    [drv drvSE]=varcomb(drv,drvSE,w);
                    barweb([sig; imm; drv]',[0;immSE;drvSE]');
                    set(gca,'xticklabel','');
                end
                ylabel 'Correlation between neurons'
                legend('Signal','Immediate','Stim-Driven');
                title (A.name);        
                
            end

            function [me sd]=varcomb(vec,sd,w)
                
                if nargin<3||isempty(w), w=ones(size(vec))/length(vec); end
                
                me=vec(:)'*w(:);
                if nargout>1
                    sd=sqrt((sd.^2)*(w(:).^2));
                end
            end
            
            
        end
        
        function Plot_Renewal(A,hax)
            % The idea of this plot is to help to identify whether the
            % spike train is a renewal process.  The top row plots pairs of
            % ISIs separated by some 'gap'.
            %
            % The bottom row plots the mutual information between ISIs as a
            % function of the gap between them.  That is, the ISIs are
            % split into n-bins according to their length, such that each
            % bin will contain a roughly equal number of ISIs.  The mutual
            % information at gap (n) is how much information, in bits,
            % ISI(i) gives about the bin of ISI(i+gap(n)).
            
            U=UIlibrary;
            
            
            if ~exist('hax','var'), 
%                 hax=U.figtype('standard',A.nN+1); 
                hF=figure;
                for k=1:A.nN
                    hax(1,k)=subplot(2,A.nN,k);
                    hax(2,k)=subplot(2,A.nN,A.nN+k);
                end
            elseif length(hax)~=A.nN, error('You supplied more axes to fill than we have cells to fill them with!'); 
            else
                hF=gcf;
            end
            A.addHelpButton;
            A.exportButton(A,'S');
            
            isiV=A.cellISI;  % cell of vector of isis's
            lag=nan;
            
            names=A.NeuronLabels;
            
            function replot
                figure(hF);
                for i=1:A.nN
                    subplot(hax(1,i)); cla;
%                     dbcheck=isiV{i}(1:end-lag);
                    plot(isiV{i}(1:end-lag),isiV{i}(lag+1:end),'+');
                    xlabel isi_i
                    ylabel (sprintf('isi_{i+%g}',lag));
                    title(strcat(A.name,' - ',names{i}));
                    axis image;
                end
                
                
            end
            
            function replotmi
                
                gaps=1:20;
                nbins=val{2}();
                [mi divs n]=A.ISI_MI(nbins,gaps);
                
                figure(hF);
                for i=1:A.nN
                    subplot(hax(2,i)); cla;
%                     dbcheck=isiV{i}(1:end-lag);
                
                    ax=plotyy(gaps,mi(i,:),gaps,n(i,:));
                    set(get(ax(1),'Ylabel'),'String','Mutual Information') 
                    set(get(ax(2),'Ylabel'),'String','Number of Samples') 
                    
                    xlabel gap
                    title(sprintf('Mutual information between ISIs (%g bins)',nbins));
                
                end
                
                                
            end
            
            
            
            function newLag
                uinp=val{1}();
                if isnan(uinp)||round(uinp)~=uinp
                    disp 'Invalid Input'
                    set(hB(1),'string',num2str(lag));
                else
                    lag=uinp;
                    replot;
                end
                
            end
            
            
            [hB val]=U.buttons({'~Lag#1','~nbins#5'});
            set(hB(1),'callback',@(s,e)newLag); % Default lag of 1
            set(hB(2),'callback',@(s,e)replotmi);
            
%             [hB2 valbin]=U.buttons(hax(end),{'ISIbins:1'});
%             set(hB2(1),'string','1','callback',@(s,e)replotmi); % Default lag of 1
            
            newLag;
            replotmi;
            
            
        end
                
        function Plot_FanoFactory(A)
            % Shows the Fano Factor (std(spike_count)/mean(spike_count)),
            % for each stimulus condition.
            
            if A.nT==1
                hW=warndlg('This dataset has only one trial.  Not much to see here.');
                uiwait(hW);
                return;
            end
            
            [FF n]=A.FanoFactor;
            
            figure;
            A.addHelpButton;
            A.exportButton(A,'S');
            
            bar(FF');
            xlabel 'Condition Number';
            ylabel 'FanoFactor';
            
            hold on;
            plot(n,'*-')
            title(A.name)
            
            legend([A.NeuronLabels 'Trial Count'])
            
        end
        
        function Plot_Raster(A,hax,hB,type)
            % The Raster-Plot
            %
            % This show the spiking data.  The viewing mode chooses how the
            % spike trains are clumped together.  For example cell, cond,
            % trial clumps first by cell, then condition, then trial.
            
            
            
           colordef black;
           
           
           figure;
           A.addHelpButton;
           A.exportButton(A,'S');
           
           if ~exist('hax','var'), hax=subplot(1,1,1); 
           
           else
               
           end
           
           function trialplot % Plotting nitty-gritty
               
               switch type{1}()
                   case 'Cell, Trial' % Sort by Trial
                       psth=A.T;         
                       trialoffsets=1:size(psth,2);
                       trialjump=ceil(trialoffsets(end)+10);
                       ylab='Neuron, Trial';
                       
                   case {'Cell,Cond,Trial' 'Cond,Trial,Cell'} % Sort trials by condition
                       
                       % Get PSTH ordering
                       [~,~,n]=unique(A.cond);
                       [~,n]=sort(n);
                       psth=A.T(:,n);
                       
                       condT=A.condTrials;                       
                       maxnum=max(cellfun(@length,condT));
                       
                       trialoffsets=cell2mat(cellfun(@(c,t) c+(0:length(t)-1)*0.6/maxnum,...
                           num2cell(1:length(condT)),condT,'uniformoutput',false));
                       
                       switch type{1}()
                           case 'Cell,Cond,Trial'
                               trialjump=ceil(trialoffsets(end)+5);
                               ylab='Neuron, Condition, Trial';
                           case 'Cond,Trial,Cell'
                               trialjump=0.1/maxnum;
                               ylab='Condition, Trial, Neuron';
                       end
                       
                       
                       
                       
                       
                       
                       
                   otherwise
                       error('wwwhatthehell');
               end
               
               % Set up plot (vertical offsets, etc)
               celloffsets=trialjump*(0:size(psth,1)-1);
               celladdcell=cell(size(psth(:,:)));
               for i=1:size(psth,1), celladdcell(i,:)={celloffsets(i)}; end
               trialaddcell=cell(size(psth(:,:)));
               for i=1:size(psth,2), trialaddcell(:,i)={trialoffsets(i)}; end
               temp=cellfun(@(x,c,t)zeros(size(x))+c+t,psth,celladdcell,trialaddcell,'uniformoutput',false);

               % Plot Spikes
               subplot(hax);
               hh=nan(1,size(psth,1));
               hold off;
               cols=lines(size(psth,1));
               ns=nan(1,size(psth,1));
               for i=1:size(psth,1);
                   mat=cell2mat(psth(i,:)');
                   ns(i)=numel(mat);
                   hh(i)=scatter(mat,cell2mat(temp(i,:)'),'+','markeredgecolor',cols(i,:));
                   hold all;
               end           
               xlabel 'time (s)';
               ylabel (ylab)

               % Plot trial-lines
               for i=1:size(psth,1);
                   addlines(trialoffsets+celloffsets(i),'h','color',[0.25 .25 .25]);
               end           
               set(gca,'children',flipud(get(gca,'children')));           
               set(gca,'ydir','reverse');

               % Title and legend
               title(A.name);
               legend(hh,A.NeuronLabels);
               
           end
           
           U=UIlibrary;
           if ~exist('val','var')
            [hB type]=U.buttons({{'Cell,Cond,Trial','Cell, Trial','Cond,Trial,Cell'}});
           end
           set(hB,'callback',@(e,s)trialplot);
           
           trialplot;
           
        end
        
        function Plot_EveryThing(A,hax)
            % Plots the smoothed signals.
            
            
            if ~exist('hax','var'), 
                figure;
                hax=arrayfun(@(i)subplot(1,A.nN,i),1:A.nN);
            end
            
            A.addHelpButton;
            A.exportButton(A,'S');
            
            % Get info
            time=A.timeVec;
            [FF mn vr]=A.FanoSmooth;
            sd=sqrt(vr);
            
            % Set user controls
            U=UIlibrary;
            [hL val]=U.buttons({{'!checklist','mean','sd','smoothed','Fano','spikes'},['~smooth#' num2str(A.sWidth)]});
%             set(hL(1),'callback',@(s,e)replot);
            set(hL(2),'callback',@(s,e)changeSmooth);
            
            opts=val{1};
            replot
            hLink=[];
            
            addlistener(hL(1),'String','PostSet',@(s,e)replot);
            
            
            function replot
                % All items should be
                % nSamples x nConditions x nNeurons matrices
                % OR (for spikes)
                % an nConditions cell array
                
%                 if isempty(opts), return; end
                
                items=struct;
                k=1;
                if opts.smoothed()
                    items(k).time=time;
                    items(k).sig=A.sTS;
                    items(k).args={};
                    items(k).name='Smoothed';
                    items(k).spacing=diff(quickclip(items(k).sig));
                    items(k).spacevec=(A.cond-1);
                    k=k+1;
                end
                
                if opts.sd()
                    items(k).time=time;
                    items(k).sig=sd;
                    items(k).args={};
                    items(k).name='std';
                    items(k).spacing=diff(quickclip(items(k).sig));
                    items(k).spacevec=1;
                    k=k+1;
                end
            
                if opts.mean()
                    items(k).time=time;
                    items(k).sig=mn;
                    items(k).args={};
                    items(k).name='mean';
                    items(k).spacing=diff(quickclip(items(k).sig));
                    items(k).spacevec=1;
                    k=k+1;
                end
                                
                if opts.Fano()
                    items(k).time=time;
                    items(k).sig=FF;
                    items(k).args={};
                    items(k).name='Fano';
                    items(k).spacing=diff(quickclip(items(k).sig));
                    items(k).spacevec=1;
                    k=k+1;
                end
                
                if opts.spikes()
                    % This one's tricky but we gonna make it work
                    v=max(cellfun(@length,A.T(:)));
                    C=cellfun(@(t)padarray(t,v-length(t),nan,'post'),A.T,'uniformoutput',false);
                    C=reshape(C,1,size(C,2),[]);
                    C=cell2mat(C);
                    
                    items(k).time=C;
                    items(k).sig=0;
                    items(k).args={'+'};
                    items(k).name='Spikes';
                    items(k).spacing=1e-14;
                    items(k).spacevec=1;
                    k=k+1;                    
                end
                
                if k>1
                    spacing=1.2*max(cat(1,items.spacing));
                else
                    return;
                end


                for i=1:length(hax)
                   subplot(hax(i));
    %                plotyy(time,mn(:,:,i),time,FF(:,:,i),@(x,y)mplot(x,y,'color','b'),@(x,y)mplot(x,y,'color','g'));
                    
                    col=lines;
                    for k=1:length(items)
                        if k==1
                            args={'showzero',true};
                        else
                            args={};
                        end
                        if isvector(items(k).time)
                            hPlot=mplot(items(k).time,items(k).sig(:,:,i),items(k).args{:},'spacing',spacing*items(k).spacevec,'color',col(k,:),args{:});
                        elseif isvector(items(k).sig)
                            hPlot=mplot(items(k).time(:,:,i),items(k).sig,items(k).args{:},'spacing',spacing*items(k).spacevec,'color',col(k,:),args{:});
                        end
                        
                        hP(k)=hPlot(1);
                        hold on;
                    end
                    hold off;
    
                    xlabel 'time(s)';
                    ylabel 'condition';
                    legend (hP,{items.name})

                    title (sprintf('Neuron %g\nSmoothing:%s\nExp:%s',A.ids(i),A.smoothDesc,A.name));
                
                    set(hax(i),'position',get(hax(i),'position')+[0 0 0 -0.05],'yticklabel',{});
                end
                
                hLink=U.linkmaxes(hax);
            
            end
            
            
            function changeSmooth
                if val{2}()>0
                    A.sWidth=val{2}();
                end
                replot;
            end
            
            
        end     
                
        function Plot_LFP(A)
            
            disp('Nothing Yet')
            
            
        end
        
        function Plot_Activity(A)
                % Plots the number of spikes in each trial or conditions.  This
            % can be useful, for instance, to see if a neuron is gradually
            % decreasing its spiking rate over the course of a recording
            % session.
            
            U=UIlibrary;
                        
            hF=figure;
            
            A.addHelpButton;
            A.exportButton(A,'S');
            hB=U.addbuttons({'Trials','Conditions'});
            
            function trialPlot
                if size(A.nS,2)==1
                    bar(A.nS);
                    xlabel 'Neuron #';
                    ylabel 'Spike Count';
                else
                    plot(A.nS','*-');
                    xlabel 'Trial #';
                    ylabel 'Spike Count';
                    legend(A.NeuronLabels);
                end
                
            end
            
            function condPlot
                
                [means stds ns]=A.condStats;
                sterr=stds./repmat(sqrt(ns),A.nN,1);
                
                errorbar(means',sterr');
                
                xlabel 'Condition #';
                ylabel 'Mean/Standard Error of Spike Counts';
                
            end
            
            function callherback(e,~)
                
                switch get(e,'value')
                    case 1, trialPlot;
                    case 2, condPlot;
                end
                
            end
            
            trialPlot;
            
            set(hB(1),'callback',@callherback)
            
            
        end
        
        function Plot_Poissonity(A)
            % This method creates a "Poisonnified" spike train by taking a
            % smoother version of the actual spike train, averaged for each
            % condition, and using it as a rate function from which to draw
            % spikes.
            %
            % It then plots the mean (over conditions) of the Fano-Factor,
            % and the mean (over trials) of the spike-count.  
            
            if A.nT==1
                hW=warndlg('This dataset has only one trial.  Not much to see here.');
                uiwait(hW);
                return;
            end
            
            % Make a comparison object
            B=Poissonification(A);
            
            figure;
            
            A.addHelpButton;
            A.exportButton(A,'S');
            
            % Fano-Factors
            FFA=squeeze(mean(A.FanoFactor,2));
            FFB=squeeze(mean(B.FanoFactor,2));
            
            % Mean Spike Count
            MCA=squeeze(mean(A.nS,2));
            MCB=squeeze(mean(B.nS,2));
            
            bar([FFA,FFB;nan nan]);
            hold on;
            plot([MCA(:);nan],'-*b');
            plot([MCB(:);nan],'-*r');
                        
            xlabel 'Neuron Number'
            ylabel 'Mean Fano-Factor (bar), and Spike-Count (line)'
            
            legend ('Data','Regenerated Spike-Train');
            
            
        end
        
        function Plot_TrialCorr(A,hax)
            % Plots the correlation matrices (between trials).  You can
            % also group trials by condition.  This is generally a good way
            % to see if the neurons are responding specifically to the
            % stimuli.  If so, spike trains responding to the same
            % condition will be much more correlated to eachother than
            % spike trains responding to different stimulus conditions.
            % 
            % When the plot is sorted condition-wise, this will show up as
            % a series of red-squares on the diagonal, with blue elsewhere.
            %
            % The "Drivenness" is the difference of the mean intra-condition
            % correlation to the mean inter-condition correlation.  A
            % drivenness around 0 indicates that the stimulus is having no
            % particular effect.  1 indicates a borderline effect, greater
            % than than becomes significant.
            
            if A.nT==1
                hW=warndlg('This dataset has only one trial.  Not much to see here.');
                uiwait(hW);
                return;
            end
%             A.mustbemulti;
            
            U=UIlibrary;
            if ~exist('hax','var')
               [hax hF]=U.figtype('standard',A.nN);
            end
            A.addHelpButton;
            A.exportButton(A,'S');
            
            R=A.trialCorrMat;
            D=A.Drivenness(R);
            [~,~,iix]=unique(A.cond);
            [~,ix]=sort(iix);
            [condT uTrials]=A.condTrials;
            counts=cumsum(cellfun(@length,condT));
            
            
            [hB val]=U.buttons({{'condition-wise','trial-wise'},'Drivenness',['~smooth#' num2str(A.sWidth)]});
                
            set(hB(1),'callback',@(e,s)replot);
            set(hB(2),'callback',@(e,s)showDrive);
            set(hB(3),'callback',@(e,s)changeSmooth);
            
            replot;
            
            
            
            function replot
                
%                 hw=waitbar(0,'Hold on...');
                
                for i=1:length(hax)
                    figure(hF);
                    subplot(hax(i));
                    switch val{1}()
                        case 'condition-wise'
                            imagesc(R(ix,ix,i));
                            addlines(counts+0.5,'h','color','k');
                            addlines(counts+0.5,'v','color','k');
                            xlabel('trials (sorted)');
                            ylabel('trials (sorted)');
                            ticks=counts-mean(diff(counts))/2+.5;
                            labels=num2str(uTrials(:));
                            set(hax(i),'XTick',ticks,'XTickLabel',labels,'YTick',ticks,'YTickLabel',labels)
                            

                        case 'trial-wise'
                            imagesc(R(:,:,i));
                            xlabel('trials');
                            ylabel('trials');
                    end
                    
                    axis square
                    title(sprintf('%s\nNeuron %g correlation matrix\nSmoothing: %s',A.name,A.ids(i),A.smoothDesc));
                    colorbar;
                end
%                 delete(hw);
            end
            
            function showDrive
                U.showtable('data',D,'ColumnName',A.NeuronLabels);
            end
            
            function changeSmooth
                hw=helpdlg('hold on');
                if val{3}()>0
                    A.sWidth=val{3}();
                end
                R=A.trialCorrMat;
                D=A.Drivenness(R);
                replot;
                delete(hw);
            end
            
        end
        
        function Plot_WinNeuronCorr(A,hax)
            % Plots the correlations between neurons over trials.
            %
            % The top plot shows the smoothed spiking histograms of the
            % two neurons, over all trials of the selected condition.
            %
            % The bottom plot has 2 modes:
            % 1) sig-noise compares the "signal correlation" - the
            %    correlation between the mean firing rates for a given
            %    condition - to the "noise correlation" - the mean over
            %    trials within a condition of the coirrelation between
            %    neurons.  These correlations are tested for a range of
            %    different lags.
            % 2) windowed - This plots the correlation between the neurons
            %    within a moving window (with 0-lag).  It shows both the
            %    signal and noise correlations of this measurement.  Note
            %    that the result often has gaps, indicating that one of the
            %    neurons produced no spikes within that window, so
            %    correlation could not be defined.
            % 
            
            U=UIlibrary;
            if ~exist('hax','var')
               hax=U.figtype('rows',2);
            end
            A.addHelpButton;
            A.exportButton(A,'S');
            
            L=A.NeuronLabels;
            tn=A.timeVec;
            
            % Initialize these guys
            [n1 n2 signal noise lags XX hLink]=deal([]);
            
            
            [hB val]=U.buttons({L L(end:-1:1) unique(A.cond) {'sig-noise' 'windowed'} '~window#1','significance'});
            
            set(hB([1 2]),'callback',@(e,s)SNcorr);
            set(hB(3:5),'callback',@(e,s)replot);
            
            
            SNcorr;
            replot;
            
            function SNcorr
                
                n1= find(strcmp(val{1}(),L)); % Neuron 1
                n2= find(strcmp(val{2}(),L)); % Neuron 2
                [signal noise lags XX]=A.SNcorr(n1,n2);
                
                replot;
            end
            
            
            function replot
               
                % Grab inputs
                
                condish=val{3}();       
                cix=find(A.cond==condish);
                n1sig=A.sTS(:,cix,n1);
                n2sig=A.sTS(:,cix,n2);
                                                
                % Plot 1 - Both Neuron signals
                subplot(hax(1))
                cla;hold on                
                hhh1=plot(tn,n1sig,'color',[.3 .3 .5]);
                hhh3=plot(tn,mean(n1sig,2),'color',[.6 .6 1],'LineWidth',2);
                hhh2=plot(tn,n2sig,'color',[.5 0 0]);       
                hhh4=plot(tn,mean(n2sig,2),'color',[1 0 0],'LineWidth',2);
                title(sprintf('%s\nCondition %g\nSmoothing: %s',A.name,condish,A.smoothDesc));
                legend([hhh1(1) hhh2(1) hhh3 hhh4],[L([n1 n2]),strcat('mean:', L([n1 n2]))]);
                
                switch val{4}()
                    case 'sig-noise'
                        set(hB([5 6]),'visible','off');
                        
                        % Plot 3 - Signal vs Noise Corr
                        subplot(hax(2)); cla
                        hhh1=plot(lags,XX(:,cix),'color',[.5 .5 .5]); hold on;
                        hhh2=plot(lags,[signal(:,condish) noise(:,condish)],'LineWidth',2);
                        xlabel('lag(s)');
                        ylabel 'Correlation Coeff'
                        legend ([hhh1(1); hhh2],'trial-corrs' ,'signal', 'noise')
                        title 'corr_N of mean_T (signal) vs mean_T of corr_N (noise)'
                        
                        
                    case 'windowed'
                                                
                        set(hB([5 6]),'visible','on');
                        
                        win=ceil(val{5}()/A.resolution);
                        
                        subplot(hax(2))
                        cla; hold on
                        title 'Be patient...Doing a pretty big calculation here'
                        drawnow;
                        
                        % Plot 2 - Calculate signals
                        C=nan(size(n1sig,1)-win,length(cix));
                        for i=1:length(cix);
                            [C(:,i) tim]=slidewincorr(n1sig(:,i),n2sig(:,i),win);
                        end             
                        tim=tim*A.resolution;
                        
                        Ccm=slidewincorr(mean(n1sig,2),mean(n2sig,2),win);
                        Cmc=mean(C,2);
                        hP1=plot(tim,C,'color',[0.5 0.5 0.5]);
                        hP2=plot(tim,Ccm,'color','w','LineWidth',2);
                        hP3=plot(tim,Cmc,'color','c','LineWidth',2);  
                        hold off;
                        legend([hP1(1) hP2 hP3],'trial-wise','corr_N-mean_T','mean_T-corr_N');
                        title (sprintf('Correlation between %s and %s\n on a %gs moving window',L{n1},L{n2},val{5}()));
                        xlabel 'time(s)'
                        
                        set(hax(2),'xlim',get(hax(1),'xlim'));
                        
                        set(hB(6),'callback',@(e,s)showsig(C,tim));
                        
                        
                        
                end
                
            end
            
            function breakitdown
                A.Give_Me_A_Break;
            end
            
            function showsig(C,tim)
                        
                hw=waitbar(0,'Hold on... calculating');

                snrk=arrayfun(@(i)signrank(C(i,:)),1:size(C,1));
                [~,tst]=arrayfun(@(i)ttest(C(i,:)),1:size(C,1));
                delete(hw);
                
                figure;
                plot(tim,[snrk' tst']);
                legend('Sign-Rank','T-Test');
                title('Probability of Null Hypothesis');

            end
            
            
        end
        
        function Plot_Stats(A,hax,stat)
            % Plot histograms of ISI times for different neurons.
            
            
            U=UIlibrary;
            if ~exist('hax','var'), hax=U.figtype('cols',A.nN); end
            if ~exist('stat','var'), stat='isi'; end
                        
            A.addHelpButton;
            A.exportButton(A,'S');
            
            % Set Regional Variables
            [Dist xlab]=deal([]);
            upperlim=0.15;   
            
            [hB val]=U.buttons({{'isi','CV'},'~upperlim#0.15'});
            
            set(hB(1),'callback',@(~,~)ChangeType);
            set(hB(2),'callback',@(~,~)upplim);
            
            PlotData;
            
            function ChangeType
                stat=val{1}();
                PlotData;
            end
                        
            function GrabData
                
                switch lower(stat)
                    case 'isi'
                        Dist=A.isidist(upperlim);
                        xlab='ISI (s)';
                    case 'cv'
                        Dist=A.CVdist(upperlim);
                        xlab='Coefficient of Variation';
                end
                
            end
                
            function PlotData
                GrabData;
                for j=1:length(Dist)
                    subplot(hax(j));
                    hist(Dist{j},40);
                    xlabel (xlab)
                    ylabel count
                    title (sprintf('%s, neuron %g',A.name,A.ids(j)));
                end      
            end
                        
            function upplim
                lim=val{2}();
                if ~isnan(lim);
                    upperlim=lim; 
                end
                
                PlotData;
            end
            
            
            
        end
        
        function Plot_FileSummary(A)
            % Shortcut to the FileCat method for plotting the file summary 
            hH=helpdlg(A.FC.summary(false),A.name);
            uiwait(hH);
            
            A.addHelpButton;
            A.exportButton(A,'S');
        end
        
        function standardButtons(A)
            A.addHelpButton;
            A.exportButton(A,'S');
        end
        
        function Plot_MeanVarHist(A)
            % Plot the histogam of spike count variances vs spike count
            % means.  The count is made by taking a sliding window across
            % repetitions of trials, and counting the mean and variance of
            % the spike count in this window (over trial-repetitions) every
            % time the window crosses a spike.  
            
            if A.nT<2, 
                errordlg('This Plot only applies to multi-trial data.  THis experiment just has one trial.');
                return;
            end
                        
            hF=figure;
            U=UIlibrary;
            [hL val]=U.buttons({'~window(s)#.5'});
            set(hL(1),'callback',@(e,s)replot);
            
            
            A.addHelpButton;
            A.exportButton(A,'S');
            
            colormap(gray);
            
            replot;
            
            function replot
                
                win=val{1}();
                
                fprintf('Building Histogram... hold up...');
                for i=1:A.nN

                    
                    [~, v, m]=RovingFanos(A.T(i,:),win,A.cond);

                    v= sqrt(cell2mat(v))';
                    m=cell2mat(m)';
                    
                    qm=quickclip(m,.95);
                    qv=quickclip(v,.95);
                    
                    
    %                 mat=fliplr(cell2mat([v;m])');

                    [N C]=hist3([v m],{linspace(0,max(qv),20),linspace(0,max(qm),20)});

                    figure(hF);
                    hax=subplot(A.nN,1,i);
                    imagesc(C{2},C{1},log10(N));
                    hc=colorbar;
                    set(hax,'ydir','normal');
                    vc=caxis;
                    caxis([-.8,vc(2)]);
                    set(hc,'yticklabel',num2str(10.^str2num(get(hc,'yticklabel')),'% 10.2f'))
                    
                    
                    va=axis;
                    hold on;
                    hP=ezplot(@(x)sqrt(x),va([1 2]));
                    set(hP,'color','r','linewidth',2);
                    plot(C{2},sum(bsxfun(@times,bsxfun(@rdivide,N,sum(N)),C{1}(:))),'b','linewidth',2);
                    hold off;
                    axis(va);
                    
                    xlabel 'mean spike count in window'
                    ylabel 'std of spike count in window';
                    title([A.name ' cell ' num2str(A.ids(i)) ' spike count']);

                    legend 'FF=1' 'Mean Standard Deviation'
                end
                disp Done
            end
            
            
        end
        
        

        
    end
    
    methods % Programming stuff
        %%

               
        function loadObj(A)
            A.setListeners;
        end
        
        function A=SpikeBanhoff
            A.setListeners;
        end
        
    end
    
    methods % Little Helpers
        %%
        function L=NeuronLabels(A)
            str=strcat('cell ',num2str(A.ids(:)));
            
            L=mat2cell(str,ones(1,size(str,1)),size(str,2))';
            
        end
                
        function desc=smoothDesc(A)
        	desc=[A.sType ',w=' num2str(A.sWidth) 's' ];
        end
        
        function mustbemulti(A)
            if A.nT==1
                hW=warndlg('This dataset has only one trial.  Not much to see here.');
                uiwait(hW);
                evalin('caller','return;');
            end
        end
    end
   
    methods % Obsolete and Comdemned
        %%
%         
%         function PlotCV2hist(A)
%             
%             figure;
%             C=A.CV2;
%             title ([A.name ': Local Coefficient of variation distribution']);
%             hist(C',20);
%             
%             xlabel('Local CV')
%             
%             legend(A.NeuronLabels);
%             
%         end
%         
%         function corrplot(A,smoothw,trains,method)
%         
%             if ~exist('trains','var'), trains=1:length(A.T); end
%             if ~exist('method','var'), method='bin'; end
%             
%             nP=length(trains)+1;
%             
%             aTS=nan(length(A.T(trains(1)).TS),length(trains));
%             for i=1:length(trains)
%                 TS(:,i)=A.T(trains(i)).SmoothSeries(smoothw,method);
%             end
%             
%             TS=A.sTS;
%             
%             figure;
%             subplot(nP,1,1);
%             plot(aTS);
%             
%             for i=1:length(trains);
%                 hold off;
%                subplot(nP,1,i+1); hold all;
%                for j=1:length(trains);
%                   if i==j, continue; end
%                   
%                   [X lags]=xcov(TS(:,i),TS(:,j),2000,'coeff');
%                   plot(lags,X);
%                                   
%                end
%                
%                
%                legend(strcat('Train ', int2str(i),  '--Train ', int2str(setdiff(trains,i)')));
%             end
%             
%             
%         end
%         
%         function ComparisonPlotter(A,type)
%                     
%             switch type
%                 case 'correlation'
%                     [ydata xdata]=A.P.xcov(A.TS,'coeff');
%                     confidence=[];
%                 case 'ttest'
%                     
%                 case 'chunkcov'
%                     
%                     
%             end
%             
%             PairwisePlot(ydata,confidence,xdata);            
%             
%         end
%             
%         function Plot_Correlations(A,varargin)
%             
%             A.ComparisonPlotter('correlation',varargin{1:end});
%             
%         end
%                 
%         function ISI_Histograms(A,nBars)
%             if ~exist('nBars','var'), nBars=50; end
%             
%             nP=size(A.T);
%             for i=1:nP
%                 subplot(nP,1,i)
%                 hist(A.isi{i},nBars);
%                 hold on;
%                 v=axis;
%                 lam=mean(1./A.isi{i});
%                 h=ezplot(@(x)1/lam*exp(-lam*x),v(1:2)); set(h,'color','r');
%                 hold off
%                 axis(v)
%             end
%             
%             
%         end
%         
%         function FanoFunction(A,hax)
%             % Built with consideration of being inserted into other plots
%             if ~exist('hax','var'), 
%                 hax=arrayfun(@(i)subplot(1,A.nN,i),1:A.nN);
%             else figure;
%             end
%             
%             % Get Info and Plot It
%             [FF mn vr]=A.FanoSmooth;
%             
%             function replot
%                 
%                 
%             
%                 time=A.timeVec;
% 
%                 q1=quickclip(FF(:));
%                 q2=quickclip(mn(:));
%                 spacing=1.2*max(diff(q1),diff(q2));
% 
% 
%                 for i=1:length(hax)
%                    subplot(hax(i));
%     %                plotyy(time,mn(:,:,i),time,FF(:,:,i),@(x,y)mplot(x,y,'color','b'),@(x,y)mplot(x,y,'color','g'));
%                     hm=mplot(time,mn(:,:,i),'spacing',spacing,'color','c');
%                     hold on;
%                     hF=mplot(time,FF(:,:,i),'spacing',spacing,'color','g');
% 
%                     xlabel 'time(s)';
%                     ylabel 'condition';
%                     legend ([hm(1) hF(1)],{'mean','FF'})
% 
%                     title (sprintf('Neuron %g',A.ids(i)));
%                 end
%             
%             end
%             
%             replot
%             
% %             U=UIlibrary;
% %             opts=U.checkMenu({'smoothed','mean','var','Fano','spikes'});
% %             U.linkmaxes(hax);
%             
%             
%             
%         end     
%         
%         function OLDraster(A)
%             
%             U=UILibrary;
%             
%             ucond=unique(A.cond);
%             
%             hF=figure;
%             hB=U.addbuttons('~Condition',num2cell(ucond),'<<','>>');
%             
%             cd=@(x)A.cond==ucond(get(hB(2),'value'));
%             
%             function condrast
%                 
%                 [u,~,n]=unique(A.cond);
%                 yarr=sort(n);
%                 
%                 
%                 
%                 
%                 
%             end
%             
%             
%             
%             
%             
%             
%             while true
%                 
%                 for i=1:size(A.T,1)
%                     
%                     vecs=reshape((A.T(i,cd(),:)),[],1);
%                     r=cell2mat(vecs);
%                     
%                     % Set vertical offset (linspace sucks)
%                     if isempty(vecs), offset=cell(0,1);
%                     else offset=num2cell(linspace(-0.2,-0.8,length(vecs)))';
%                     end
%                     
%                     loc=cell2mat(cellfun(@(x,n)repmat(n+1-i,size(x)),...
%                         vecs,offset,'uniformoutput',false));
% 
%                     scatter(r,loc,'+');
%                     
%                     hold all;
%                 end
%                 hold off;
%                 
%                 title (sprintf('Raster plot of response to condition %g',A.cond(find(cd(),1))));
%                 
%                 uiwait(hF);
%                 if isempty(gco), break; end
%                 
%                 switch gco
%                     case hB(3) % back
%                         if get(hB(2),'value')>1
%                             set(hB(2),'value',get(hB(2),'value')-1);
%                         end                    
%                     case hB(4), % forward
%                         if get(hB(2),'value')<length(ucond)
%                             set(hB(2),'value',get(hB(2),'value')+1);
%                         end
%                     
%                     
%                 end
%                 
%             end
%             
%         end
%         
%         function plot(A,trains)
%             if ~exist('trains','var'), trains=1:length(A.T); end
%             
%             time=A.timeVec;
%             
%             mplot(A.timeVec, A.TS);
%             
% %             plot(time,A.TS+repmat(0:-1.5:-1.5*(size(A.T,1)-1),[size(A.TS,1) 1]));
%             
%             legend(strcat('Neuron ', int2str(trains(:)), ': ' ,int2str([A.nS]'),' spikes'))
% 
%         end
%         
%         function Load_Neuro_Data(A,spikes,LFP,LFP_fS)
%             
%             A.resolution=LFP_fS;
%             A.LFP=LFP;
%             A.Train_Factory(spikes);
%             
%             
%         end
%         
%         function Train_Factory(A,eventList,spikecol)
%             
%             % Get data, convert to s
%             if iscell(eventList)
%                 mat=cell2mat(eventList);
%             else
%                 mat=eventList;
%             end
%             
%             if ~exist('spikecol','var')
%                 lst=all(mat(1:10,:)==round(mat(1:10,:)));
%                 spikecol=find(~lst);
%                 idcol=find(lst);
%                 if ~xor(lst(1),lst(2))
%                     error('Some shit''s gone crazy wrong!');
%                 end
%                     
%             end
%                         
%             cells=unique(mat(:,idcol));
%             mat(:,spikecol)=mat(:,spikecol)/1000;
%             
%             % Check for screwups
%             whoops=find(diff(mat(:,spikecol))<0,1);
%             if ~isempty(whoops)
%                 disp 'Warning: Data''s Messed.  We''ll just take the good bit.'
%                 mat(whoops+1:end,:)=[];
%             end
%             
%             % Load the data
%             if isempty(A.endtime)
%                 A.endtime=mat(end,spikecol);
%             end
%             for i=1:length(cells)
%                ix=mat(:,idcol)==cells(i);               
%                A.T{i}=mat(ix,spikecol);
%             end
%             
%         end
%         
        
    end
    
    methods (Static)
        
        function S=go
           S=SpikeBanhoff;
           S.GrabCat;
        end
        
        
    end
    
end


function h=PairwisePlot(lines,confidence,xdata)
    % This takes care of the ugliness of plotting pairwise comparisons.
    % Handles are returned so you can play with the graphs as you wish.
    

    doX=exist('xdata','var')&&~isempty(xdata);
    doC=exist('confidence','var')&&~isempty(confidence);
    if doC
        if numel(confidence{1,1})==2*length(confidence{1,1})
            intervalsMade;
        else
            for i=1:numel(lines)
               confidence{i}=[lines{i}(:)+confidence{i}(:) lines{i}(:)-confidence{i}(:)]; 
            end
        end
    end
    
    nP=length(lines);
    h=nan(nP);
    figure;
    for i=1:nP
       for j=1:nP
           h(i,j)=subplot(nP,nP,fix(nP*(i-1))+j);
           if doC
               if doX, plot(xdata{i,j},confidence{i,j},'color',[.5 .5 .5]);
               else     plot(confidence{i,j},'color',[.5 .5 .5]);
               end
           end
           
           hold on
           if doX,  plot(xdata{i,j},lines{i,j},'g');
           else     plot(lines{i,j});
           end
           hold off
           
       end        
    end
    
end

