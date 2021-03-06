function A=ScriptoCats(opt)
% =========================================================================
% ScriptoCats (<a href="matlab:A=ScriptoCats">Run</a>) (<a href="matlab:edit('ScriptoCats')">Edit</a>)
% 
% Welcome to ScriptoCats.  This script contains the functions and parameters
% that a user can edit to extract statistics from the cat data.  Click the 
% "Edit" button above to see this script, or the "Run" to start it.    
%
% You will first be prompted to select some cats from the list.  If there's
% a cat not already in the list, you can add one through the GUI.  If you
% then save, it'll be there next time you open.  Internally, this is all
% taken care of by the <a href="matlab:help('FelineFileFinder')">FelineFileFinder</a> object.
%
% After selecting a list of cats, you will be returned to the base
% workspace, with a nice GUI that allows you to view data extracted from
% the experiments, along with the statistics that you defined in this file.
% 
% In the base workspace, you will find the object A.  Through this, you can
% access all the data from all the cats.  For instance ">>A.C(4).S" will
% return an object containing all the Spike-Train data for cat 4.  The name
% of cat 4 can be found by ">>A.C(4).name".  "A.C(4).S.T{2,5}" returns the
% spike times for the 2nd neuron from the 5th trial for cat 4.
%
% Basic Map of Object (not all properties, no methods shown)
% A: <a href="matlab:edit('CatParliament')">CatParliament</a> object, used for extracting statistics from these experiments. 
%  Properties:
%   .stats: Structure array of statistics, with fields 'name','fun'.  See
%       ScriptoCat for how to build this array.
%   .groups: Structure array of groups, with fields 'name','fun'.  See
%       ScriptoCat for how to build this array.
%   .filter: Handle to function with boolean output and StimCat (see below)
%       input which decides whether to extract statistics from that cat.
%       Leave empty to extract stats from all cats.
%   .preproc: Handle to function that takes a StimCat (see below) input and
%       performs some kind of pre-processing.  Leave empty if you don't
%       want to do any preprocessing.
%   .D: Cell array containing results of calculations.  D{i,j} contains the
%       result of calculating statistic j on experiment i.
%   .C: Array of <a href="matlab:help('MinistersCat')">MinistersCat</a> objects, each representing a single penetration. 
%       .E: Array of <a href="matlab:edit('StimCat')">StimCat</a> objects, each representing a single experiment. 
%         Propeties:
%           .name: Name of the experiment
%           .type: Type (one of 'tuning','whitenoise','movies')
%           .D: Object containing data on the stimulus.
%           .FC: <a href="matlab:edit('FileCat')">FileCat</a> object, used for getting Raw Data.
%           .K: Structure defining Kernal as obtained from RevCorr Method (not
%               shown here - just works for whitenoise experiments)
%           .S: <a href="matlab:edit('SpikeBanhoff')">SpikeBanhoff</a> object. Contains the spiking data, 
%               and methods to view and interpret it.
%             Properties:
%               .T: Cell array containing spike times.  Indexed by {neuron, trial}
%               .isi: Equivalent cell array, containing ISI's.
%               .TS: Matrix containing binary-binned representation of spike
%                   train .resolution property (not shown here) defines binning
%               .sTS: Smoothed version of TS.  See .sWidth and .sType for
%                   smoothing kernel properties (not shown here).
%               .FC: <a href="matlab:help('FileCat')">FileCat</a> object, used for getting Raw Data. 
%       .whi: Shortcut referring to first "whitenoise" StimCat in array "E"
%       .tun: Shortcut referring to first "tuning" StimCat in array "E"
%       .mov: Shortcut referring to first "movies" StimCat in array "E"
%       .S: Shortcut referring to SpikeBanhoff objects in array E.  A.S(i)
%           refers to the same object as A.C(i).S
%       .ids: List of ids of neurons in this set of experiments.
% 
% To Skip this whole help screen in the future, just run A=ScriptoCat in
% the command line.
% 
% =========================================================================

% Just run A=ScriptoCat in the command line to run this directly.

if nargout==0
    help(mfilename);
    return;
end
colordef black;

if ~exist('opt','var'), opt='full'; end

% evalin('base','close all hidden; clear classes; clc;');

A=CatParliament;
if ~A.loadCats, return; end
A.copyCats=false;       % copyCats=true mean you copy the object, and leave the original, before doing the preprocessing and statistics.  


%% Define Groups of interest
% Note that groups of interest can also be declaired in the statistic
% definition.

A.groups(1).name='tuning';
A.groups(1).fun=@(MC)MC.tun; 

A.groups(2).name='movies';
A.groups(2).fun=@(MC)MC.mov; 

A.groups(3).name='whitenoise';
A.groups(3).fun=@(MC)MC.whi; 


%% Define Statistics of Interest

switch lower(opt)
    case 'full',        setFull(A)
    case 'meanvarhist', setMeanVarHist(A)
    case 'x',           setX(A)
    case 'rmi',         setRMI(A)
    case 'combined',    setCombined(A)
end

%% A lil' filtering
A.minSpikesFilter(1);   % Filter experiments with less than 1 spike/trial on average.

%% Get 'er done

A.crunch;
A.GUI;

end

function setFull(A)

    A.filter=@filterFun;
    A.preproc=@preProc;

    A.stats(1).name='MeanFano 0.5';
    % A.stats(1).fun=@(SC)mean(SC.S.FanoFactor);
    A.stats(1).fun=@(SC)mean(cell2mat(RovingFanos(SC.S.T,0.5,SC.S.cond)));
    A.stats(1).groups=[1 2];

    A.stats(2).name='Subsequent ISI Mutual Information (6 divisions)';
    A.stats(2).fun=@(SC)mean(SC.S.ISI_MI(6,1),2);

    A.stats(3).name='Spike Count';
    A.stats(3).fun=@(SC)sum(squeeze(SC.S.nS));

    A.stats(4).name='Median Kurtosis';
    A.stats(4).fun=@(SC)median(SC.S.isi_kurtosis);

    A.stats(5).name='Mean CV2';
    A.stats(5).fun=@(SC)cellfun(@(x)mean(x),SC.S.CVdist);

    A.stats(6).name='Mean Spike Rate';
    A.stats(6).fun=@(SC)SC.S.meanSpikeRate;

    A.stats(7).name='MaxMeanIntraTrialCorr'; 
    A.stats(7).fun=@(SC)max(SC.S.intraTrialCorr);
    A.stats(7).groups=[1 2];

%     A.stats(8).name='MaxPeriodicity'; 
%     A.stats(8).fun=@(SC)max(SC.S.periodicity);
%     A.stats(8).groups=[1];

%     A.stats(9).name='Structure';
%     A.stats(9).fun=@structurefun;
%     function st=structurefun(SC)
%         % A measure of the structure of the signal.  Basically just the
%         % relative strength of the non-DC component to the DC.
%         X=abs(fft(SC.S.TS));
%         st=bsxfun(@rdivide,mean(X(1:fix(end/2),:)),X(1,:));
%         st=mean(st(~isnan(st)));
%     end

%     A.stats(8).name='Max Drivenness';
%     A.stats(8).fun=@(SC)max(SC.S.Drivenness);
%     A.stats(8).groups=[1 2];


    A.splitCells; % Divide the cells

    
    
end

function setMeanVarHist(A)

%     A.filter=@filterFun;
%     A.preproc=@preProc;

    win=0.5; % seconds
    maxStd=20; % Spikes in the window
    maxMean=70; % Spikes in thw window
    meanbins=linspace(0,maxMean,20);
    varbins=linspace(0,maxStd,20);


    A.stats(1).name='Mean Var Hist';
    A.stats(1).fun=@meanvarhist;
    A.stats(1).groups=[1 2];

    A.splitCells; % Divide the cells

%     A.splitTypes;
    
    A.extra=@()plotMeanVars(A);

    function N=meanvarhist(SC)
                
        [~, v, m]=RovingFanos(SC.S.T(1,:),win,SC.S.cond);
        
        v= sqrt(cell2mat(v))';
        m=cell2mat(m)';
        
        N=hist3([v m],{varbins,meanbins});
        N=N/sum(N(:));
        
    end
 
    function plotMeanVars(A)
        
        valids=cellfun(@(x)~isempty(x)&&~isnan(x(1)),A.D);
        
        types=repmat({A.groups.name},length(A.C),1);
        
        types=types(valids(:));
        
        CVlist=cell2mat(reshape(A.D(valids),1,1,[]));
        
        figure;
        colormap(gray);
        imagesc(meanbins,varbins,log10(mean(CVlist,3)));
        
        set(gca,'ydir','normal');
        vc=caxis;
        caxis([vc(1)-diff(vc)/4,vc(2)]);
        
        hc=colorbar;
        set(hc,'yticklabel',num2str(10.^str2num(get(hc,'yticklabel'))))

        va=axis;
        hold on;
        hP=ezplot(@(x)sqrt(x),va([1 2]));
        set(hP,'color','r','linewidth',2);
        
        means=sum(bsxfun(@times,bsxfun(@rdivide,CVlist,sum(CVlist,1)),varbins(:)));
        
        ixm=find(strcmp(types,'movies'));
        ixt=find(strcmp(types,'tuning'));
        
        [mem sdm nm met sdt nt]=deal(nan(1,size(means,2)));
        for i=1:length(mem)
            ixmv=ixm(~isnan(means(1,i,ixm)));
            mem(i)=mean(means(1,i,ixmv),3);
            sdm(i)=std(means(1,i,ixmv),[],3);
            nm(i)=nnz(ixmv);
            
            ixtv=ixt(~isnan(means(1,i,ixt)));
            met(i)=mean(means(1,i,ixtv),3);
            sdt(i)=std(means(1,i,ixtv),[],3);
            nt(i)=nnz(ixtv);
                        
        end
        
        sp=min(diff(meanbins));
        
        hM=errorbar(meanbins-.1*sp,mem,sdm,'b','linewidth',2);
        errorbar(meanbins-.1*sp,mem,sdm./sqrt(nm),'b','linewidth',2);
        
        hT=errorbar(meanbins+.1*sp,met,sdt,'linewidth',2,'color',[0 .5 0]);
        errorbar(meanbins+.1*sp,met,sdt./sqrt(nt),'linewidth',2,'color',[0 .5 0]);
        
        hold off;
        axis(va);

        xlabel 'mean spike count in window'
        ylabel 'std of spike count in window';
        title(['mean proportion of total spikes ' num2str(win) 's moving window']);

        legend([hP hM hT], 'FF=1', 'Mean,SD,SE over neurons of mean SD over windows (movies)', 'Mean,SD,SE over neurons of mean SD over windows (tuning)', 'location', 'northoutside')
        

        
    end
    
    
    
    
    
end

function setX(A)

    A.filter=[];
    A.preproc=@kernelset;

    A.stats(1).name='Inter-Neuron Correlation';
    
    A.stats(1).dimnames={'Signal','Immediate','Stim-Driven'};
    A.stats(1).groups=[1 2];
    
    A.stats(1).fun=@corrStats;
    function co=corrStats(SC)
        
        [sig imm drv]=SC.S.SNcorr(SC.S.ids(1),SC.S.ids(2),0);
        
        nnS=SC.S.nS;
        w=cellfun(@(ix)sum(geomean(nnS(:,ix))),SC.S.condTrials);
        w=w/sum(w);
        
        co=[sig*w',imm*w',drv*w'];
        
    end
    
end

function setCombined(A)

    A.stats(1).name='Relative Mutual Info';
    A.stats(1).fun=@relMutInfo;
    A.stats(1).groups=[1 2];
    A.stats(1).dimnames={'Subsequent','Artificial'};

    A.splitCells;

    
    function MI=relMutInfo(SC)
        
        f=XX('isicomp');
        
        MI=f(SC.S);
        
        [r sig]=rMutualInformation(MI{1},8,5);
        
        MI=r([2 6]); % will get r(1,2) and r(2,3)
        
    end

end

function valid=filterFun(MC)
    %% Test whether to run file.
            
    if all(ismember({'tuning','movies','whitenoise'},{MC.E.type}))
        valid=true;
    else
        valid=false;
    end
    
end

function preProc(M)
    %% PreProcessing Commands to run
        
    % Cut it down to just a single type of each experiment
    M.E=[M.mov M.tun M.whi];
    
    % Select the most active cell over the 3 of them...
    M.takeMaxCell;
    
    for i=1:length(M.E)
        M.E(i).S.sWidth=0.2;            % Smoothing kernel width to 0.2s
        M.E(i).S.sType='gauss';         % Gaussinan smothing kernek (width is fwhh)
%         M.E(i).S.cropTimes([0 2]);      % Trim the trials.
    end
    
end

function kernelset(M)

    for i=1:length(M.E)
        M.E(i).S.sWidth=0.05;            % Smoothing kernel width to 0.2s
        M.E(i).S.sType='gauss';         % Gaussinan smothing kernek (width is fwhh)
%         M.E(i).S.cropTimes([0 2]);      % Trim the trials.
    end

end
