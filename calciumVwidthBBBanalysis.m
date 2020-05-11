% get the data you need 
vidList = [1,2,3,4,5,7]; %SF56
% vidList = [1,2,3,4,5,6]; %SF57
tData = cell(1,length(vidList));
cDataFullTrace = cell(1,length(vidList));
for vid = 1:length(vidList)
    temp1 = matfile(sprintf('SF56_20190718_ROI2_%d_Fdata_termTtype.mat',vidList(vid)));
    tData{vid} = temp1.GtTdataTerm;  
    cDataFullTrace{vid} = temp1.CcellData;  
end 
FPSstack = temp1.FPSstack;
framePeriod = temp1.framePeriod;
state = 8;
terminals = [13,20,12,16,11,15,10,8,9,7,4]; %SF56
% terminals = [17,15,12,10,8,7,6,5,4,3]; %SF57

bDataFullTrace = cell(1,length(vidList));
vDataFullTrace = cell(1,length(vidList));
for vid = 1:length(vidList)
    temp2 = matfile(sprintf('SF56_20190718_ROI2_%d_CVBdata_F-SB_terminalWOnoiseFloor_CaPeakAlignedData.mat',vidList(vid)));
    bDataFullTrace{vid} = temp2.Bdata; 
    vDataFullTrace{vid} = temp2.Vdata; 
end 

temp3 = matfile('SF56_20190718_ROI2_1-5_7_10_BBB.mat');
Bdata = temp3.dataToPlot;

temp4 = matfile('SF56_20190718_ROI2_1-3_5_7_VW.mat');
Vdata = temp4.dataToPlot;

temp5 = matfile('SF56_20190718_ROI2_1-3_5_7_VW_and_1-5_7_10CaData.mat');
ROIinds = temp5.ROIinds;

TrialTypes = cell(1,length(vidList));
state_start_f = cell(1,length(vidList));
state_end_f = cell(1,length(vidList));
trialLength = cell(1,length(vidList));
for vid = 1:length(vidList)
    [~,stateStartF,stateEndF,FPS,vel_wheel_data,TrialType] = makeHDFchart_redBlueStim(state,framePeriod);
    TrialTypes{vid} = TrialType(1:length(stateStartF),:);
    state_start_f{vid} = floor(stateStartF/3);
    state_end_f{vid} = floor(stateEndF/3);
    trialLength{vid} = state_end_f{vid} - state_start_f{vid};
    
    %make sure the trial lengths are the same per trial type 
    %set ideal trial lengths 
    lenT1 = floor(FPSstack*2); % 2 second trials 
    lenT2 = floor(FPSstack*20); % 20 second trials 
    %identify current trial lengths 
    [kIdx,kMeans] = kmeans(trialLength{vid},2);
    %edit kMeans list so trialLengths is what they should be 
    for len = 1:length(kMeans)
        if kMeans(len)-lenT1 < abs(kMeans(len)-lenT2)
            kMeans(len) = lenT1;
        elseif kMeans(len)-lenT1 > abs(kMeans(len)-lenT2)
            kMeans(len) = lenT2;
        end 
    end 
    %change state_end_f so all trial lengths match up 
    for trial = 1:length(state_start_f{vid})
        state_end_f{vid}(trial,1) = state_start_f{vid}(trial)+kMeans(kIdx(trial));
    end 
    trialLength{vid} = state_end_f{vid} - state_start_f{vid};   
end 
%% reorganize trial data 
%{
Cdata = cell(1,length(tData{1}{1}));
for term = 1:length(tData{1}{1})
    for tType = 1:length(tData{1})
        trial2 = 1; 
        for vid = 1:length(tData)            
            if isempty(tData{vid}{tType}) == 0 
                for trial = 1:size(tData{vid}{tType}{term},1)
                    Cdata{term}{tType}(trial2,:) = tData{vid}{tType}{term}(trial,:); 
                    trial2 = trial2 + 1;
                end 
            end             
        end 
    end 
end 

%average across z and different vessel segments 
VdataNoROIarray = cell(1,length(Vdata));
VdataNoROI = cell(1,length(Vdata));
VdataNoZ = cell(1,length(Bdata));
VdataNoZarray = cell(1,length(Bdata));
for tType = 1:length(Bdata) 
    for z = 1:length(Vdata)        
        for ROI = 1:length(Vdata{z})   
            for trial = 1:length(Vdata{z}{ROI}{tType})
                VdataNoROIarray{z}{tType}{trial}(ROI,:) = Vdata{z}{ROI}{tType}{trial};             
                VdataNoROI{z}{tType}{trial} = nanmean(VdataNoROIarray{z}{tType}{trial},1);
                VdataNoZarray{tType}{trial}(z,:) = VdataNoROI{z}{tType}{trial};                
                VdataNoZ{tType}{trial} = nanmean(VdataNoZarray{tType}{trial},1);
            end
        end 
        
    end 
end 
clear Vdata 
Vdata = VdataNoZ;

%resample if you need to
for tType = 1:length(Bdata)
    for trial = 1:length(Bdata{tType})
        if length(Cdata{1}{tType}) ~= length(Bdata{tType}{trial})
            Bdata{tType}{trial} = resample(Bdata{tType}{trial},length(Cdata{1}{tType}),length(Bdata{tType}{trial}));
        end 
    end 
    for trial = 1:length(Vdata{tType})
        if length(Cdata{1}{tType}) ~= length(Vdata{tType}{trial})
            Vdata{tType}{trial} = resample(Vdata{tType}{trial},length(Cdata{1}{tType}),length(Vdata{tType}{trial}));
        end 
    end 
end 
%}
%% smooth trial data if you want
%{
smoothQ =  input('Do you want to smooth your data? Yes = 1. No = 0. ');
if smoothQ ==  1
    filtTime = input('How many seconds do you want to smooth your data by? ');
    sCdata = cell(1,length(Cdata));
    for term = 1:length(Cdata)
        for tType = 1:length(Cdata{1})   
            for trial = 1:size(Cdata{term}{tType},1)
                [sC_Data] = MovMeanSmoothData(Cdata{term}{tType}(trial,:),filtTime,FPSstack);
                sCdata{term}{tType}(trial,:) = sC_Data; 
            end 
        end 
    end 
    
    sBdata = cell(1,length(Bdata));
    for tType = 1:length(Bdata)   
        for trial = 1:length(Bdata{tType})
            [sB_Data] = MovMeanSmoothData(Bdata{tType}{trial},filtTime,FPSstack);
            sBdata{tType}(trial,:) = sB_Data;             
        end 
    end 

    sVdata = cell(1,length(Vdata));
    for tType = 1:length(Vdata)   
        for trial = 1:length(Vdata{tType})
            [sV_Data] = MovMeanSmoothData(Vdata{tType}{trial},filtTime,FPSstack);
            sVdata{tType}(trial,:) = sV_Data;             
        end 
    end     
    
elseif smoothQ == 0
    sCdata = Cdata; 
    sBdata = cell(1,length(Bdata));
    for tType = 1:length(Bdata)   
        for trial = 1:length(Bdata{tType})
            sBdata{tType}(trial,:) = Bdata{tType}{trial};
        end 
    end 
    sVdata = cell(1,length(Vdata));
    for tType = 1:length(Vdata)   
        for trial = 1:length(Vdata{tType})
            sVdata{tType}(trial,:) = Vdata{tType}{trial};
        end 
    end     
end 
%}
%% plot event triggered averages per terminal 
%{
for term = 1:length(Data)
    AVdata = cell(1,length(Data{1}));
    SEMdata = cell(1,length(Data{1}));
    baselineEndFrame = floor(20*(FPSstack));
    for tType = 4%1:length(Data{1})      
        if isempty(Data{term}{tType}) == 0          
            AVdata{tType} = mean(sData{term}{tType},1);
            SEMdata{tType} = std(sData{term}{tType},1)/sqrt(size(Data{term}{tType},1));
            figure;             
            hold all;
            if tType == 1 || tType == 3 
                Frames = size(Data{term}{tType},2);        
                Frames_pre_stim_start = -((Frames-1)/2); 
                Frames_post_stim_start = (Frames-1)/2; 
                sec_TimeVals = floor(((Frames_pre_stim_start:FPSstack*2:Frames_post_stim_start)/FPSstack)+1);
                FrameVals = floor((1:FPSstack*2:Frames)-1); 
            elseif tType == 2 || tType == 4 
                Frames = size(Data{term}{tType},2);
                Frames_pre_stim_start = -((Frames-1)/2); 
                Frames_post_stim_start = (Frames-1)/2; 
                sec_TimeVals = floor(((Frames_pre_stim_start:FPSstack*2:Frames_post_stim_start)/FPSstack)+10);
                FrameVals = floor((1:FPSstack*2:Frames)-1); 
            end 
            if tType == 1 
                plot([round(baselineEndFrame+((FPSstack)*2)) round(baselineEndFrame+((FPSstack)*2))], [-5000 5000], 'b','LineWidth',2)
                plot([baselineEndFrame baselineEndFrame], [-5000 5000], 'b','LineWidth',2) 
        %                 patch([baselineEndFrame round(baselineEndFrame+((FPS/numZplanes)*2)) round(baselineEndFrame+((FPS/numZplanes)*2)) baselineEndFrame],[-5000 -5000 5000 5000],'b')
        %                 alpha(0.5)   
            elseif tType == 3 
                plot([round(baselineEndFrame+((FPSstack)*2)) round(baselineEndFrame+((FPSstack)*2))], [-5000 5000], 'r','LineWidth',2)
                plot([baselineEndFrame baselineEndFrame], [-5000 5000], 'r','LineWidth',2) 
        %                 patch([baselineEndFrame round(baselineEndFrame+((FPS/numZplanes)*2)) round(baselineEndFrame+((FPS/numZplanes)*2)) baselineEndFrame],[-5000 -5000 5000 5000],'r')
        %                 alpha(0.5)                       
            elseif tType == 2 
                plot([round(baselineEndFrame+((FPSstack)*20)) round(baselineEndFrame+((FPSstack)*20))], [-5000 5000], 'b','LineWidth',2)
                plot([baselineEndFrame baselineEndFrame], [-5000 5000], 'b','LineWidth',2) 
        %                 patch([baselineEndFrame round(baselineEndFrame+((FPS/numZplanes)*20)) round(baselineEndFrame+((FPS/numZplanes)*20)) baselineEndFrame],[-5000 -5000 5000 5000],'b')
        %                 alpha(0.5)   
            elseif tType == 4 
                plot([round(baselineEndFrame+((FPSstack)*20)) round(baselineEndFrame+((FPSstack)*20))], [-5000 5000], 'r','LineWidth',2)
                plot([baselineEndFrame baselineEndFrame], [-5000 5000], 'r','LineWidth',2) 
        %                 patch([baselineEndFrame round(baselineEndFrame+((FPS/numZplanes)*20)) round(baselineEndFrame+((FPS/numZplanes)*20)) baselineEndFrame],[-5000 -5000 5000 5000],'r')
        %                 alpha(0.5)  
            end
            colorSet = varycolor(size(Data{term}{tType},1));
            for trial = 1:size(Data{term}{tType},1)
                plot(sData{term}{tType}(trial,:),'Color',colorSet(trial,:),'LineWidth',1.5)
            end 
            plot(AVdata{tType},'k','LineWidth',3)
            ax=gca;
            ax.XTick = FrameVals;
            ax.XTickLabel = sec_TimeVals;
            ax.FontSize = 20;
            xlim([0 Frames])
            ylim([-200 200])
            xlabel('time (s)')
            if smoothQ == 1
                title(sprintf('Terminal #%d data smoothed by %0.2f sec',terminals(term),filtTime));
            elseif smoothQ == 0
                title(sprintf('Terminal #%d raw data',terminals(term)));
            end 
        end 
    end 
end 

% plot event triggered averages per terminal (trials staggered) 
for term = 1:length(Data)
    AVdata = cell(1,length(Data{1}));
    SEMdata = cell(1,length(Data{1}));
    baselineEndFrame = floor(20*(FPSstack));
    for tType = 4%1:length(Data{1})      
        if isempty(Data{term}{tType}) == 0          
            AVdata{tType} = mean(sData{term}{tType},1);
            SEMdata{tType} = std(sData{term}{tType},1)/sqrt(size(Data{term}{tType},1));
            figure;             
            hold all;
            if tType == 1 || tType == 3 
                Frames = size(Data{term}{tType},2);        
                Frames_pre_stim_start = -((Frames-1)/2); 
                Frames_post_stim_start = (Frames-1)/2; 
                sec_TimeVals = floor(((Frames_pre_stim_start:FPSstack*2:Frames_post_stim_start)/FPSstack)+1);
                FrameVals = floor((1:FPSstack*2:Frames)-1); 
            elseif tType == 2 || tType == 4 
                Frames = size(Data{term}{tType},2);
                Frames_pre_stim_start = -((Frames-1)/2); 
                Frames_post_stim_start = (Frames-1)/2; 
                sec_TimeVals = floor(((Frames_pre_stim_start:FPSstack*2:Frames_post_stim_start)/FPSstack)+10);
                FrameVals = floor((1:FPSstack*2:Frames)-1); 
            end 
            colorSet = varycolor(size(Data{term}{tType},1));
            yStagTerm = 300;
            trialList = cell(1,size(Data{term}{tType},1));
            for trial = 1:size(Data{term}{tType},1)
                plot(sData{term}{tType}(trial,:)+yStagTerm,'LineWidth',1,'Color',colorSet(trial,:),'LineWidth',1.5)
                yStagTerm = yStagTerm + 300;
                trialList{trial} = sprintf('trial %d',trial);
            end 
            if tType == 1 
                plot([round(baselineEndFrame+((FPSstack)*2)) round(baselineEndFrame+((FPSstack)*2))], [-5000 5000], 'b','LineWidth',2)
                plot([baselineEndFrame baselineEndFrame], [-5000 5000], 'b','LineWidth',2) 
        %                 patch([baselineEndFrame round(baselineEndFrame+((FPS/numZplanes)*2)) round(baselineEndFrame+((FPS/numZplanes)*2)) baselineEndFrame],[-5000 -5000 5000 5000],'b')
        %                 alpha(0.5)   
            elseif tType == 3 
                plot([round(baselineEndFrame+((FPSstack)*2)) round(baselineEndFrame+((FPSstack)*2))], [-5000 5000], 'r','LineWidth',2)
                plot([baselineEndFrame baselineEndFrame], [-5000 5000], 'r','LineWidth',2) 
        %                 patch([baselineEndFrame round(baselineEndFrame+((FPS/numZplanes)*2)) round(baselineEndFrame+((FPS/numZplanes)*2)) baselineEndFrame],[-5000 -5000 5000 5000],'r')
        %                 alpha(0.5)                       
            elseif tType == 2 
                plot([round(baselineEndFrame+((FPSstack)*20)) round(baselineEndFrame+((FPSstack)*20))], [-5000 5000], 'b','LineWidth',2)
                plot([baselineEndFrame baselineEndFrame], [-5000 5000], 'b','LineWidth',2) 
        %                 patch([baselineEndFrame round(baselineEndFrame+((FPS/numZplanes)*20)) round(baselineEndFrame+((FPS/numZplanes)*20)) baselineEndFrame],[-5000 -5000 5000 5000],'b')
        %                 alpha(0.5)   
            elseif tType == 4 
                plot([round(baselineEndFrame+((FPSstack)*20)) round(baselineEndFrame+((FPSstack)*20))], [-5000 5000], 'r','LineWidth',2)
                plot([baselineEndFrame baselineEndFrame], [-5000 5000], 'r','LineWidth',2) 
        %                 patch([baselineEndFrame round(baselineEndFrame+((FPS/numZplanes)*20)) round(baselineEndFrame+((FPS/numZplanes)*20)) baselineEndFrame],[-5000 -5000 5000 5000],'r')
        %                 alpha(0.5)  
            end
            ax=gca;
            ax.XTick = FrameVals;
            ax.XTickLabel = sec_TimeVals;
            ax.FontSize = 20;
            xlim([0 Frames])
            ylim([0 2500])
            xlabel('time (s)')
            if smoothQ == 1
                title(sprintf('Terminal #%d data smoothed by %0.2f sec',terminals(term),filtTime));
            elseif smoothQ == 0
                title(sprintf('Terminal #%d raw data',terminals(term)));
            end          
            legend(trialList)
        end 
    end 
end 
%}
%% plot event triggered averages of relevant terminals averaged together 
%{
%define the terminals you want to average 
% terms = input('What terminals do you want to average? ');

termGdata = cell(1,length(Cdata{1}));
for tType = 1:length(Cdata{1}) 
    for term = 1:length(terms)
        ind = find(terminals == (terms(term)));
        if term == 1 
            termGdata{tType} = sCdata{ind}{tType};
        elseif term > 1
            termGdata{tType}(((term-1)*size(Cdata{ind}{tType},1))+1:term*size(Cdata{ind}{tType},1),:) = sCdata{ind}{tType};
        end          
    end 
end 

cAVdata = cell(1,length(Cdata{1}));
cSEMdata = cell(1,length(Cdata{1}));
bAVdata = cell(1,length(Cdata{1}));
bSEMdata = cell(1,length(Cdata{1}));
vAVdata = cell(1,length(Cdata{1}));
vSEMdata = cell(1,length(Cdata{1}));
baselineEndFrame = floor(20*(FPSstack));
for tType = 4%1:length(cData{1}) 
    cAVdata{tType} = nanmean(termGdata{tType},1);
    cSEMdata{tType} = std(termGdata{tType},1)/sqrt(size(termGdata{tType},1));    
    bAVdata{tType} = nanmean(sBdata{tType},1);
    bSEMdata{tType} = std(sBdata{tType},1)/sqrt(size(sBdata{tType},1));    
    vAVdata{tType} = nanmean(sVdata{tType},1);
    vSEMdata{tType} = std(sVdata{tType},1)/sqrt(size(sVdata{tType},1));
    
    figure;                 
    hold all;
    if tType == 1 || tType == 3 
        Frames = size(termGdata{tType},2);        
        Frames_pre_stim_start = -((Frames-1)/2); 
        Frames_post_stim_start = (Frames-1)/2; 
        sec_TimeVals = floor(((Frames_pre_stim_start:FPSstack*2:Frames_post_stim_start)/FPSstack)+1);
        FrameVals = floor((1:FPSstack*2:Frames)-1); 
    elseif tType == 2 || tType == 4 
        Frames = size(termGdata{tType},2);
        Frames_pre_stim_start = -((Frames-1)/2); 
        Frames_post_stim_start = (Frames-1)/2; 
        sec_TimeVals = floor(((Frames_pre_stim_start:FPSstack*2:Frames_post_stim_start)/FPSstack)+10);
        FrameVals = floor((1:FPSstack*2:Frames)-1); 
    end 
    if tType == 1 
        plot([round(baselineEndFrame+((FPSstack)*2)) round(baselineEndFrame+((FPSstack)*2))], [-5000 5000], 'b','LineWidth',2)
        plot([baselineEndFrame baselineEndFrame], [-5000 5000], 'b','LineWidth',2) 
%                 patch([baselineEndFrame round(baselineEndFrame+((FPS/numZplanes)*2)) round(baselineEndFrame+((FPS/numZplanes)*2)) baselineEndFrame],[-5000 -5000 5000 5000],'b')
%                 alpha(0.5)   
    elseif tType == 3 
        plot([round(baselineEndFrame+((FPSstack)*2)) round(baselineEndFrame+((FPSstack)*2))], [-5000 5000], 'r','LineWidth',2)
        plot([baselineEndFrame baselineEndFrame], [-5000 5000], 'r','LineWidth',2) 
%                 patch([baselineEndFrame round(baselineEndFrame+((FPS/numZplanes)*2)) round(baselineEndFrame+((FPS/numZplanes)*2)) baselineEndFrame],[-5000 -5000 5000 5000],'r')
%                 alpha(0.5)                       
    elseif tType == 2 
        plot([round(baselineEndFrame+((FPSstack)*20)) round(baselineEndFrame+((FPSstack)*20))], [-5000 5000], 'b','LineWidth',2)
        plot([baselineEndFrame baselineEndFrame], [-5000 5000], 'b','LineWidth',2) 
%                 patch([baselineEndFrame round(baselineEndFrame+((FPS/numZplanes)*20)) round(baselineEndFrame+((FPS/numZplanes)*20)) baselineEndFrame],[-5000 -5000 5000 5000],'b')
%                 alpha(0.5)   
    elseif tType == 4 
        plot([round(baselineEndFrame+((FPSstack)*20)) round(baselineEndFrame+((FPSstack)*20))], [-5000 5000], 'r','LineWidth',2)
        plot([baselineEndFrame baselineEndFrame], [-5000 5000], 'r','LineWidth',2) 
%                 patch([baselineEndFrame round(baselineEndFrame+((FPS/numZplanes)*20)) round(baselineEndFrame+((FPS/numZplanes)*20)) baselineEndFrame],[-5000 -5000 5000 5000],'r')
%                 alpha(0.5)  
    end
    for trial = 1:size(termGdata{tType},1)
        plot(termGdata{tType}(trial,:),'LineWidth',1)
    end 
    plot(cAVdata{tType},'k','LineWidth',3)
    ax=gca;
    ax.XTick = FrameVals;
    ax.XTickLabel = sec_TimeVals;
    ax.FontSize = 20;
    xlim([0 Frames])
    ylim([-200 200])
    xlabel('time (s)')
    if smoothQ == 1
        title(sprintf('calcium data smoothed by %0.2f sec',filtTime));
    elseif smoothQ == 0
        title('raw calcium data');
    end 
end 

for tType = 4%1:length(cData{1}) 
    figure;                 
    hold all;
    if tType == 1 || tType == 3 
        Frames = size(termGdata{tType},2);        
        Frames_pre_stim_start = -((Frames-1)/2); 
        Frames_post_stim_start = (Frames-1)/2; 
        sec_TimeVals = floor(((Frames_pre_stim_start:FPSstack*2:Frames_post_stim_start)/FPSstack)+1);
        FrameVals = floor((1:FPSstack*2:Frames)-1); 
    elseif tType == 2 || tType == 4 
        Frames = size(termGdata{tType},2);
        Frames_pre_stim_start = -((Frames-1)/2); 
        Frames_post_stim_start = (Frames-1)/2; 
        sec_TimeVals = floor(((Frames_pre_stim_start:FPSstack*2:Frames_post_stim_start)/FPSstack)+10);
        FrameVals = floor((1:FPSstack*2:Frames)-1); 
    end 
    if tType == 1 
        plot([round(baselineEndFrame+((FPSstack)*2)) round(baselineEndFrame+((FPSstack)*2))], [-5000 5000], 'b','LineWidth',2)
        plot([baselineEndFrame baselineEndFrame], [-5000 5000], 'b','LineWidth',2) 
%                 patch([baselineEndFrame round(baselineEndFrame+((FPS/numZplanes)*2)) round(baselineEndFrame+((FPS/numZplanes)*2)) baselineEndFrame],[-5000 -5000 5000 5000],'b')
%                 alpha(0.5)   
    elseif tType == 3 
        plot([round(baselineEndFrame+((FPSstack)*2)) round(baselineEndFrame+((FPSstack)*2))], [-5000 5000], 'r','LineWidth',2)
        plot([baselineEndFrame baselineEndFrame], [-5000 5000], 'r','LineWidth',2) 
%                 patch([baselineEndFrame round(baselineEndFrame+((FPS/numZplanes)*2)) round(baselineEndFrame+((FPS/numZplanes)*2)) baselineEndFrame],[-5000 -5000 5000 5000],'r')
%                 alpha(0.5)                       
    elseif tType == 2 
        plot([round(baselineEndFrame+((FPSstack)*20)) round(baselineEndFrame+((FPSstack)*20))], [-5000 5000], 'b','LineWidth',2)
        plot([baselineEndFrame baselineEndFrame], [-5000 5000], 'b','LineWidth',2) 
%                 patch([baselineEndFrame round(baselineEndFrame+((FPS/numZplanes)*20)) round(baselineEndFrame+((FPS/numZplanes)*20)) baselineEndFrame],[-5000 -5000 5000 5000],'b')
%                 alpha(0.5)   
    elseif tType == 4 
        plot([round(baselineEndFrame+((FPSstack)*20)) round(baselineEndFrame+((FPSstack)*20))], [-5000 5000], 'r','LineWidth',2)
        plot([baselineEndFrame baselineEndFrame], [-5000 5000], 'r','LineWidth',2) 
%                 patch([baselineEndFrame round(baselineEndFrame+((FPS/numZplanes)*20)) round(baselineEndFrame+((FPS/numZplanes)*20)) baselineEndFrame],[-5000 -5000 5000 5000],'r')
%                 alpha(0.5)  
    end
    for trial = 1:size(sBdata{tType},1)
        plot(sBdata{tType}(trial,:),'LineWidth',1)
    end 
    plot(bAVdata{tType},'k','LineWidth',3)
    ax=gca;
    ax.XTick = FrameVals;
    ax.XTickLabel = sec_TimeVals;
    ax.FontSize = 20;
    xlim([0 Frames])
    ylim([-3 3])
    xlabel('time (s)')
    if smoothQ == 1
        title(sprintf('BBB data smoothed by %0.2f sec',filtTime));
    elseif smoothQ == 0
        title('raw BBB data');
    end 
end 

for tType = 4%1:length(cData{1}) 
    figure;                 
    hold all;
    if tType == 1 || tType == 3 
        Frames = size(termGdata{tType},2);        
        Frames_pre_stim_start = -((Frames-1)/2); 
        Frames_post_stim_start = (Frames-1)/2; 
        sec_TimeVals = floor(((Frames_pre_stim_start:FPSstack*2:Frames_post_stim_start)/FPSstack)+1);
        FrameVals = floor((1:FPSstack*2:Frames)-1); 
    elseif tType == 2 || tType == 4 
        Frames = size(termGdata{tType},2);
        Frames_pre_stim_start = -((Frames-1)/2); 
        Frames_post_stim_start = (Frames-1)/2; 
        sec_TimeVals = floor(((Frames_pre_stim_start:FPSstack*2:Frames_post_stim_start)/FPSstack)+10);
        FrameVals = floor((1:FPSstack*2:Frames)-1); 
    end 
    if tType == 1 
        plot([round(baselineEndFrame+((FPSstack)*2)) round(baselineEndFrame+((FPSstack)*2))], [-5000 5000], 'b','LineWidth',2)
        plot([baselineEndFrame baselineEndFrame], [-5000 5000], 'b','LineWidth',2) 
%                 patch([baselineEndFrame round(baselineEndFrame+((FPS/numZplanes)*2)) round(baselineEndFrame+((FPS/numZplanes)*2)) baselineEndFrame],[-5000 -5000 5000 5000],'b')
%                 alpha(0.5)   
    elseif tType == 3 
        plot([round(baselineEndFrame+((FPSstack)*2)) round(baselineEndFrame+((FPSstack)*2))], [-5000 5000], 'r','LineWidth',2)
        plot([baselineEndFrame baselineEndFrame], [-5000 5000], 'r','LineWidth',2) 
%                 patch([baselineEndFrame round(baselineEndFrame+((FPS/numZplanes)*2)) round(baselineEndFrame+((FPS/numZplanes)*2)) baselineEndFrame],[-5000 -5000 5000 5000],'r')
%                 alpha(0.5)                       
    elseif tType == 2 
        plot([round(baselineEndFrame+((FPSstack)*20)) round(baselineEndFrame+((FPSstack)*20))], [-5000 5000], 'b','LineWidth',2)
        plot([baselineEndFrame baselineEndFrame], [-5000 5000], 'b','LineWidth',2) 
%                 patch([baselineEndFrame round(baselineEndFrame+((FPS/numZplanes)*20)) round(baselineEndFrame+((FPS/numZplanes)*20)) baselineEndFrame],[-5000 -5000 5000 5000],'b')
%                 alpha(0.5)   
    elseif tType == 4 
        plot([round(baselineEndFrame+((FPSstack)*20)) round(baselineEndFrame+((FPSstack)*20))], [-5000 5000], 'r','LineWidth',2)
        plot([baselineEndFrame baselineEndFrame], [-5000 5000], 'r','LineWidth',2) 
%                 patch([baselineEndFrame round(baselineEndFrame+((FPS/numZplanes)*20)) round(baselineEndFrame+((FPS/numZplanes)*20)) baselineEndFrame],[-5000 -5000 5000 5000],'r')
%                 alpha(0.5)  
    end
    for trial = 1:size(sVdata{tType},1)
        plot(sVdata{tType}(trial,:),'LineWidth',1)
    end 
    plot(vAVdata{tType},'k','LineWidth',3)
    ax=gca;
    ax.XTick = FrameVals;
    ax.XTickLabel = sec_TimeVals;
    ax.FontSize = 20;
    xlim([0 Frames])
    ylim([-3 3])
    xlabel('time (s)')
    if smoothQ == 1
        title(sprintf('vessel width smoothed by %0.2f sec',filtTime));
    elseif smoothQ == 0
        title('raw vessel width');
    end 
end 

%}
%% compare terminal calcium activity - create correlograms
%{
AVdata = cell(1,length(Cdata));
for term = 1:length(Cdata)
    for tType = 1:length(Cdata{1})      
        AVdata{term}{tType} = mean(sCdata{term}{tType},1);
    end 
end 

dataQ = input('Input 0 if you want to compare the entire TS. Input 1 if you want to compare stim period data. Input 2 if you want to compare baseline period data.');
if dataQ == 0 
    corData = cell(1,length(Cdata{1}));
    corAVdata = cell(1,length(Cdata{1}));
    for tType = 1:length(Cdata{1})    
       for term1 = 1:length(Cdata)
           for term2 = 1:length(Cdata)
               for trial = 1:size(Cdata{1}{tType},1)
                   corData{tType}{trial}(term1,term2) = corr2(sCdata{term1}{tType}(trial,:),sCdata{term2}{tType}(trial,:));                  
               end 
               corAVdata{tType}(term1,term2) = corr2(AVdata{term1}{tType},AVdata{term2}{tType});
           end 
       end 
    end 
elseif dataQ == 1 
    corData = cell(1,length(Cdata{1}));
    corAVdata = cell(1,length(Cdata{1}));
    for tType = 1:length(Cdata{1})    
       for term1 = 1:length(Cdata)
           for term2 = 1:length(Cdata)
               stimOnFrame = floor(FPSstack*20);
               if tType == 1 || tType == 3 
                   stimOffFrame = stimOnFrame + floor(FPSstack*20);
               elseif tType == 2 || tType == 4
                   stimOffFrame = stimOnFrame + floor(FPSstack*2);
               end 
               for trial = 1:size(Cdata{1}{tType},1)
                   corData{tType}{trial}(term1,term2) = corr2(sCdata{term1}{tType}(trial,stimOnFrame:stimOffFrame),sCdata{term2}{tType}(trial,stimOnFrame:stimOffFrame));
               end 
               corAVdata{tType}(term1,term2) = corr2(AVdata{term1}{tType}(stimOnFrame:stimOffFrame),AVdata{term2}{tType}(stimOnFrame:stimOffFrame));
           end 
       end 
    end 
elseif dataQ == 2
    corData = cell(1,length(Cdata{1}));
    corAVdata = cell(1,length(Cdata{1}));
    for tType = 1:length(Cdata{1})    
       for term1 = 1:length(Cdata)
           for term2 = 1:length(Cdata)
               baselineEndFrame = floor(FPSstack*20);
               for trial = 1:size(Cdata{1}{tType},1)
                   corData{tType}{trial}(term1,term2) = corr2(sCdata{term1}{tType}(trial,1:baselineEndFrame),sCdata{term2}{tType}(trial,1:baselineEndFrame));
               end 
               corAVdata{tType}(term1,term2) = corr2(AVdata{term1}{tType}(1:baselineEndFrame),AVdata{term2}{tType}(1:baselineEndFrame));
           end 
       end 
    end 
end 

% plot cross correlelograms 
for tType = 1:length(Cdata{1})
    % plot averaged trial data
    figure;
    imagesc(corAVdata{tType})
    colorbar 
    truesize([700 900])
    ax=gca;
    ax.FontSize = 20;
    ax.XTickLabel = terminals;
    ax.YTickLabel = terminals;
    if smoothQ == 0 
       if tType == 1 
           title('2 sec blue stim. Raw data.','FontSize',20);
       elseif tType == 2
           title('20 sec blue stim. Raw data.','FontSize',20);
       elseif tType == 3
           title('2 sec red stim. Raw data.','FontSize',20);
       elseif tType == 4 
           title('20 sec red stim. Raw data.','FontSize',20);
       end 
    elseif smoothQ == 1
       if tType == 1 
           mtitle = sprintf('2 sec blue stim. Data smoothed by %0.2f sec.',filtTime);
           title(mtitle,'FontSize',20);
       elseif tType == 2
           mtitle = sprintf('20 sec blue stim. Data smoothed by %0.2f sec.',filtTime);
           title(mtitle,'FontSize',20);
       elseif tType == 3
           mtitle = sprintf('2 sec red stim. Data smoothed by %0.2f sec.',filtTime);
           title(mtitle,'FontSize',20);
       elseif tType == 4 
           mtitle = sprintf('20 sec red stim. Data smoothed by %0.2f sec.',filtTime);
           title(mtitle,'FontSize',20);
       end 
    end 
   xlabel('terminal')
   ylabel('terminal')
    
   %plot trial data 
   figure;
    if smoothQ == 0 
       if tType == 1 
           sgtitle('2 sec blue stim. Raw data.','FontSize',20);
       elseif tType == 2
           sgtitle('20 sec blue stim. Raw data.','FontSize',20);
       elseif tType == 3
           sgtitle('2 sec red stim. Raw data.','FontSize',20);
       elseif tType == 4 
           sgtitle('20 sec red stim. Raw data.','FontSize',20);
       end 
    elseif smoothQ == 1
       if tType == 1 
           mtitle = sprintf('2 sec blue stim. Data smoothed by %0.2f sec.',filtTime);
           sgtitle(mtitle,'FontSize',20);
       elseif tType == 2
           mtitle = sprintf('20 sec blue stim. Data smoothed by %0.2f sec.',filtTime);
           sgtitle(mtitle,'FontSize',20);
       elseif tType == 3
           mtitle = sprintf('2 sec red stim. Data smoothed by %0.2f sec.',filtTime);
           sgtitle(mtitle,'FontSize',20);
       elseif tType == 4 
           mtitle = sprintf('20 sec red stim. Data smoothed by %0.2f sec.',filtTime);
           sgtitle(mtitle,'FontSize',20);
       end 
    end 
   for trial = 1:size(Cdata{1}{tType},1)
       subplot(2,4,trial)
       imagesc(corData{tType}{trial})
       colorbar 
       ax=gca;
       ax.FontSize = 12;
       title(sprintf('Trial #%d.',trial));
%        truesize([200 400])
       xlabel('terminal')
       ylabel('terminal')
       ax.XTick = (1:length(terminals));
       ax.YTick = (1:length(terminals));
       ax.XTickLabel = terminals;
       ax.YTickLabel = terminals;
   end 
end 
%}
%% calcium peak raster plots 
%{
Len1_3 = length(sData{1}{1});
Len2_4 = length(sData{1}{2});

% peaks = cell(1,length(Data));
locs = cell(1,length(Data));
stdTrace = cell(1,length(Data));
sigPeaks = cell(1,length(Data));
sigPeakLocs = cell(1,length(Data));
clear raster raster2 raster3 
for term = 1:length(Data)
%     figure;
    for tType = 4%1:length(Data{1})   
        for trial = 1:size(Data{term}{tType},1)
            %identify where the peaks are 
            [peak, loc] = findpeaks(sData{term}{tType}(trial,:),'MinPeakProminence',0.1,'MinPeakWidth',2); %0.6,0.8,0.9,1
            peaks{term}{tType}{trial} = peak;
            locs{term}{tType}{trial} = loc;
            stdTrace{term}(trial,tType) = std(sData{term}{tType}(trial,:));
            count = 1;
            if isempty(peaks{term}{tType}{trial}) == 0 
                for ind = 1:length(peaks{term}{tType}{trial})
                    if peaks{term}{tType}{trial}(ind) > stdTrace{term}(trial,tType)*2
                        sigPeakLocs{term}{tType}{trial}(count) = locs{term}{tType}{trial}(ind);
                        sigPeaks{term}{tType}{trial}(count) = peaks{term}{tType}{trial}(ind);                   
                        %create raster plot by binarizing data                      
                        raster2{term}{tType}(trial,sigPeakLocs{term}{tType}{trial}(count)) = 1;
                       count = count + 1;
                    end                
                end 
            end 
        end 
    end 
end 
for term = 1:length(peaks)
%     figure;
    for tType = 4%1:length(peaks{1})   
        for trial = 1:size(peaks{term}{tType},1)
            if isempty(peaks{term}{tType}{trial}) == 0
                raster2{term}{tType} = ~raster2{term}{tType};
                %make raster plot larger/easier to look at 
                RowMultFactor = 10;
                ColMultFactor = 1;
                raster3{term}{tType} = repelem(raster2{term}{tType},RowMultFactor,ColMultFactor);
                raster{term}{tType} = repelem(raster2{term}{tType},RowMultFactor,ColMultFactor);
                %make rasters the correct length  
                if tType == 1 || tType == 3
                    raster{term}{tType}(:,length(raster3{term}{tType})+1:Len1_3) = 1;
                elseif tType == 2 || tType == 4   
                    raster{term}{tType}(:,length(raster3{term}{tType})+1:Len2_4) = 1;
                end 
%        
%                 %create image 
%                 subplot(2,2,tType)
%                 imshow(raster{term}{tType})
%                 hold all 
%                 stimStartF = floor(FPSstack*20);
%                 if tType == 1 || tType == 3
%                     stimStopF = stimStartF + floor(FPSstack*2);           
%                     Frames = size(raster{term}{tType},2);        
%                     Frames_pre_stim_start = -((Frames-1)/2); 
%                     Frames_post_stim_start = (Frames-1)/2; 
%                     sec_TimeVals = floor(((Frames_pre_stim_start:FPSstack*4:Frames_post_stim_start)/FPSstack)+1);
%                     FrameVals = floor((1:FPSstack*4:Frames)-1);            
%                 elseif tType == 2 || tType == 4       
%                     stimStopF = stimStartF + floor(FPSstack*20);            
%                     Frames = size(raster{term}{tType},2);        
%                     Frames_pre_stim_start = -((Frames-1)/2); 
%                     Frames_post_stim_start = (Frames-1)/2; 
%                     sec_TimeVals = floor(((Frames_pre_stim_start:FPSstack*4:Frames_post_stim_start)/FPSstack)+10);
%                     FrameVals = floor((1:FPSstack*4:Frames)-1);
%                 end 
%                 if tType == 1 || tType == 2
%                 plot([stimStartF stimStartF], [0 size(raster{term}{tType},1)], 'b','LineWidth',2)
%                 plot([stimStopF stimStopF], [0 size(raster{term}{tType},1)], 'b','LineWidth',2)
%                 elseif tType == 3 || tType == 4
%                 plot([stimStartF stimStartF], [0 size(raster{term}{tType},1)], 'r','LineWidth',2)
%                 plot([stimStopF stimStopF], [0 size(raster{term}{tType},1)], 'r','LineWidth',2)
%                 end 
%         
%                 ax=gca;
%                 axis on 
%                 xticks(FrameVals)
%                 ax.XTickLabel = sec_TimeVals;
%                 yticks(5:10:size(raster{term}{tType},1)-5)
%                 ax.YTickLabel = ([]);
%                 ax.FontSize = 15;
%                 xlabel('time (s)')
%                 ylabel('trial')
%                 sgtitle(sprintf('Terminal %d',terminals(term)))
            end 
        end 
    end 
end 

%
 %create raster for all terminals stacked 
for tType = 4%1:length(Data{1})   
    for term = 1:length(Data)
        curRowSize = size(raster{term}{tType},1);
        if curRowSize < size(sData{term}{tType},1)*RowMultFactor 
            raster{term}{tType}(curSize+1:size(sData{term}{tType},1)*RowMultFactor,:) = 1;
        end    
    end 
end 

clear fullRaster
fullRaster = cell(1,length(Data{1}));
for tType = 4%1:length(Data{1})   
    rowLen = size(raster{term}{tType},1);
    for term = 1:length(Data)
        if term == 1
            fullRaster{tType} = raster{term}{tType};
        elseif term > 1
            fullRaster{tType}(((term-1)*rowLen)+1:term*rowLen,:) = raster{term}{tType};
        end 
    end 
    %create image 
%     subplot(2,2,tType)
    imshow(fullRaster{tType})
    hold all 
    stimStartF = floor(FPSstack*20);
    if tType == 1 || tType == 3
        stimStopF = stimStartF + floor(FPSstack*2);           
        Frames = size(fullRaster{tType},2);        
        Frames_pre_stim_start = -((Frames-1)/2); 
        Frames_post_stim_start = (Frames-1)/2; 
        sec_TimeVals = floor(((Frames_pre_stim_start:FPSstack*4:Frames_post_stim_start)/FPSstack)+1);
        FrameVals = floor((1:FPSstack*4:Frames)-1);            
    elseif tType == 2 || tType == 4       
        stimStopF = stimStartF + floor(FPSstack*20);            
        Frames = size(fullRaster{tType},2);        
        Frames_pre_stim_start = -((Frames-1)/2); 
        Frames_post_stim_start = (Frames-1)/2; 
        sec_TimeVals = floor(((Frames_pre_stim_start:FPSstack*4:Frames_post_stim_start)/FPSstack)+10);
        FrameVals = floor((1:FPSstack*4:Frames)-1);
    end 
    if tType == 1 || tType == 2
    plot([stimStartF stimStartF], [0 size(fullRaster{tType},1)], 'b','LineWidth',2)
    plot([stimStopF stimStopF], [0 size(fullRaster{tType},1)], 'b','LineWidth',2)
    elseif tType == 3 || tType == 4
    plot([stimStartF stimStartF], [0 size(fullRaster{tType},1)], 'r','LineWidth',2)
    plot([stimStopF stimStopF], [0 size(fullRaster{tType},1)], 'r','LineWidth',2)
    end 

    ax=gca;
    axis on 
    xticks(FrameVals)
    ax.XTickLabel = sec_TimeVals;
    yticks(5:10:size(fullRaster{tType},1)-5)
    ax.YTickLabel = ([]);
    ax.FontSize = 10;
    xlabel('time (s)')
    ylabel('trial')
%     sgtitle(sprintf('Terminal %d',terminals(term)))
end
%}
%% plot peak rate per every n seconds 
 %{
winSec = input('How many seconds do you want to know the calcium peak rate? '); 
winFrames = floor(winSec*FPSstack);
numPeaks = cell(1,length(Data));
avTermNumPeaks = cell(1,length(Data));
for term = 1:length(Data)
%     figure
    for tType = 4%1:length(Data{1})
        windows = ceil(length(raster2{term}{tType})/winFrames);
        for win = 1:windows
            if win == 1 
                numPeaks{term}{tType}(:,win) = sum(~raster2{term}{tType}(:,1:winFrames),2);
            elseif win > 1 
                if ((win-1)*winFrames)+1 < length(raster2{term}{tType}) && winFrames*win < length(raster2{term}{tType})
                    numPeaks{term}{tType}(:,win) = sum(~raster2{term}{tType}(:,((win-1)*winFrames)+1:winFrames*win),2);
                end 
            end 
            avTermNumPeaks{term}{tType} = nanmean(numPeaks{term}{tType},1);
        end 

%         %create plots per terminal  
%         subplot(2,2,tType)
%         hold all 
%         stimStartF = floor((FPSstack*20)/winFrames);
%         if tType == 1 || tType == 3
%             stimStopF = stimStartF + floor((FPSstack*2)/winFrames);           
%             Frames = size(avTermNumPeaks{term}{tType},2);        
%             sec_TimeVals = (0:winSec*2:winSec*Frames)-20;
%             FrameVals = (0:2:Frames);            
%         elseif tType == 2 || tType == 4       
%             stimStopF = stimStartF + floor((FPSstack*20)/winFrames);            
%             Frames = size(avTermNumPeaks{term}{tType},2);        
%             sec_TimeVals = (1:winSec*2:winSec*(Frames+1))-21;
%             FrameVals = (0:2:Frames);
%         end 
%         if tType == 1 || tType == 2
%         plot([stimStartF stimStartF], [-20 20], 'b','LineWidth',2)
%         plot([stimStopF stimStopF], [-20 20], 'b','LineWidth',2)
%         elseif tType == 3 || tType == 4
%         plot([stimStartF stimStartF], [-20 20], 'r','LineWidth',2)
%         plot([stimStopF stimStopF], [-20 20], 'r','LineWidth',2)
%         end 
%         for trial = 1:size(numPeaks{term}{tType},1)
%             plot(numPeaks{term}{tType}(trial,:))
%         end 
%         plot(avTermNumPeaks{term}{tType},'k','LineWidth',2)
% 
%         ax=gca;
%         axis on 
%         xticks(FrameVals)
%         ax.XTickLabel = sec_TimeVals;
% %         yticks(5:10:size(avTermNumPeaks{term}{tType},1)-5)
% %         ax.YTickLabel = ([]);
%         ax.FontSize = 10;
%         xlabel('time (s)')
%         ylabel('trial')
%         xlim([1 length(avTermNumPeaks{term}{tType})])
%         ylim([-1 5])
%         mtitle = sprintf('Number of calcium peaks. Terminal %d.',terminals(term));
%         sgtitle(mtitle);
    end 
end 

allTermAvPeakNums = cell(1,length(Data{1}));
for term = 1:length(Data)
    for tType = 4%1:length(Data{1})
        colNum = floor(length(sData{term}{tType})/winFrames); 
        if length(avTermNumPeaks{term}{tType}) < colNum
            avTermNumPeaks{term}{tType}(length(avTermNumPeaks{term}{tType})+1:colNum) = 0;
        end 
        allTermAvPeakNums{tType}(term,:) = avTermNumPeaks{term}{tType};
    end 
end 

%plot num peaks for all terminals (terminal traces overlaid)
for tType = 4%1:length(Data{1})
%     subplot(2,2,tType)
    hold all 
    stimStartF = floor((FPSstack*20)/winFrames);
    if tType == 1 || tType == 3
        stimStopF = stimStartF + floor((FPSstack*2)/winFrames);           
        Frames = size(allTermAvPeakNums{tType},2);        
        sec_TimeVals = (0:winSec*2:winSec*Frames)-20;
        FrameVals = (0:2:Frames);            
    elseif tType == 2 || tType == 4       
        stimStopF = stimStartF + floor((FPSstack*20)/winFrames);            
        Frames = size(allTermAvPeakNums{tType},2);        
        sec_TimeVals = (1:winSec*2:winSec*(Frames+1))-21;
        FrameVals = (0:2:Frames);
    end 
    colorSet = varycolor(length(Data));
    for term = 1:length(Data)
        plot(allTermAvPeakNums{tType}(term,:),'Color',colorSet(term,:),'LineWidth',1.5)
    end 
    plot(mean(allTermAvPeakNums{tType}),'Color','k','LineWidth',2)
%     plot(allTermAvPeakNums{tType},'Color','k')
%     for col = 1:length(allTermAvPeakNums{tType})
%         scatter(linspace(col,col,size(allTermAvPeakNums{tType},1)),allTermAvPeakNums{tType}(:,col))
%     end 
    if tType == 1 || tType == 2
        plot([stimStartF stimStartF], [-20 20], 'b','LineWidth',2)
        plot([stimStopF stimStopF], [-20 20], 'b','LineWidth',2)
    elseif tType == 3 || tType == 4
        plot([stimStartF stimStartF], [-20 20], 'r','LineWidth',2)
        plot([stimStopF stimStopF], [-20 20], 'r','LineWidth',2)
    end 
    ax=gca;
    axis on 
    xticks(FrameVals)
    ax.XTickLabel = sec_TimeVals;
%         yticks(5:10:size(avTermNumPeaks{term}{tType},1)-5)
%         ax.YTickLabel = ([]);
    ax.FontSize = 10;
    xlabel('time (s)')
    ylabel('number of peaks')
    xlim([0 length(avTermNumPeaks{term}{tType})])
    ylim([-0.5 1])
    sgtitle('Number of calcium peaks per terminal');
    legend('terminal 13','terminal 20','terminal 12','terminal 16','terminal 11','terminal 15','terminal 10','terminal 8','terminal 9','terminal 7','terminal 4')
end 

%plot num peaks for all terminals (terminal traces stacked - not overlaid)
figure;
for tType = 4%1:length(Data{1})
%     subplot(2,2,tType)
    hold all 
    stimStartF = floor((FPSstack*20)/winFrames);
    if tType == 1 || tType == 3
        stimStopF = stimStartF + floor((FPSstack*2)/winFrames);           
        Frames = size(allTermAvPeakNums{tType},2);        
        sec_TimeVals = (0:winSec*2:winSec*Frames)-20;
        FrameVals = (0:2:Frames);            
    elseif tType == 2 || tType == 4       
        stimStopF = stimStartF + floor((FPSstack*20)/winFrames);            
        Frames = size(allTermAvPeakNums{tType},2);        
        sec_TimeVals = (1:winSec*2:winSec*(Frames+1))-21;
        FrameVals = (0:2:Frames);
    end 
    colorSet = varycolor(length(Data));
    yStagTerm = 0.7;
    for term = 1:length(Data)
        plot(allTermAvPeakNums{tType}(term,:)+yStagTerm,'Color',colorSet(term,:),'LineWidth',1.5)
        yStagTerm = yStagTerm + 0.7;
    end 
%     plot(mean(allTermAvPeakNums{tType}),'Color','k','LineWidth',2)
%     plot(allTermAvPeakNums{tType},'Color','k')
%     for col = 1:length(allTermAvPeakNums{tType})
%         scatter(linspace(col,col,size(allTermAvPeakNums{tType},1)),allTermAvPeakNums{tType}(:,col))
%     end 
    if tType == 1 || tType == 2
        plot([stimStartF stimStartF], [-20 20], 'b','LineWidth',2)
        plot([stimStopF stimStopF], [-20 20], 'b','LineWidth',2)
    elseif tType == 3 || tType == 4
        plot([stimStartF stimStartF], [-20 20], 'r','LineWidth',2)
        plot([stimStopF stimStopF], [-20 20], 'r','LineWidth',2)
    end 
    ax=gca;
    axis on 
    xticks(FrameVals)
    ax.XTickLabel = sec_TimeVals;
%         yticks(5:10:size(avTermNumPeaks{term}{tType},1)-5)
%         ax.YTickLabel = ([]);
    ax.FontSize = 10;
    xlabel('time (s)')
    ylabel('number of peaks')
    xlim([0 length(avTermNumPeaks{term}{tType})])
    ylim([0 8.5])
    sgtitle('Number of calcium peaks per terminal');
    legend('terminal 17','terminal 15','terminal 12','terminal 10','terminal 8','terminal 7','terminal 6','terminal 5','terminal 4','terminal 3')
end 
%}
%% find calcium peaks per terminal across entire experiment 
%{
% find peaks and then plot where they are in the entire TS 
stdTrace = cell(1,length(vidList));
sigPeaks = cell(1,length(vidList));
sigLocs = cell(1,length(vidList));
for vid = 1:length(vidList)
    for ccell = 1:length(terminals)
        ind = find(ROIinds == terminals(ccell));
        %find the peaks 
        [peaks, locs] = findpeaks(cDataFullTrace{vid}{ind},'MinPeakProminence',0.1,'MinPeakWidth',2); %0.6,0.8,0.9,1\
        %find the sig peaks (peaks above 2 standard deviations from mean) 
        stdTrace{vid}{ind} = std(cDataFullTrace{vid}{ind});  
        count = 1 ; 
        for loc = 1:length(locs)
            if peaks(loc) > stdTrace{vid}{ind}*2
                sigPeaks{vid}{ind}(count) = peaks(loc);
                sigLocs{vid}{ind}(count) = locs(loc);
                plot([locs(loc) locs(loc)], [-5000 5000], 'k','LineWidth',2)
                count = count + 1;
            end 
        end 
                
        % below is plotting code 
        %{
        Frames = size(cDataFullTrace{vid}{ind},2);
        Frames_pre_stim_start = -((Frames-1)/2); 
        Frames_post_stim_start = (Frames-1)/2; 
        sec_TimeVals = floor(((Frames_pre_stim_start:FPSstack*50:Frames_post_stim_start)/FPSstack)+51);
        min_TimeVals = round(sec_TimeVals/60,2);
        FrameVals = round((1:FPSstack*50:Frames)-1); 
        figure;
        ax=gca;
        hold all
        plot(cDataFullTrace{vid}{ind},'Color',[0 0.5 0],'LineWidth',1)
        for trial = 1:size(state_start_f{vid},1)
            if TrialTypes{vid}(trial,2) == 1
                plot([state_start_f{vid}(trial) state_start_f{vid}(trial)], [-5000 5000], 'b','LineWidth',2)
                plot([state_end_f{vid}(trial) state_end_f{vid}(trial)], [-5000 5000], 'b','LineWidth',2)
            elseif TrialTypes{vid}(trial,2) == 2
                plot([state_start_f{vid}(trial) state_start_f{vid}(trial)], [-5000 5000], 'r','LineWidth',2)
                plot([state_end_f{vid}(trial) state_end_f{vid}(trial)], [-5000 5000], 'r','LineWidth',2)
            end 
        end 
        ax.XTick = FrameVals;
        ax.XTickLabel = min_TimeVals;
        ax.FontSize = 20;
        xlim([0 size(cDataFullTrace{vid}{ind},2)])
        ylim([-200 200])
        xlabel('time (min)')
        if smoothQ ==  1
            title({sprintf('terminal #%d data',terminals(ccell)); sprintf('smoothed by %0.2f seconds',filtTime)})
        elseif smoothQ == 0 
            title(sprintf('terminal #%d raw data',terminals(ccell)))
        end        
        %}
    end 
end 
%}
%% sort data based on ca peak location 
%{
windSize = 5; %input('How big should the window be around Ca peak in seconds?');

sortedCdata = cell(1,length(vidList));
sortedBdata = cell(1,length(vidList));
sortedVdata = cell(1,length(vidList));
for vid = 1:length(vidList)
    for ccell = 1:length(terminals)
        ind = find(ROIinds == terminals(ccell));
        for peak = 1:length(sigLocs{vid}{ind})            
            if sigLocs{vid}{ind}(peak)-floor((windSize/2)*FPSstack) > 0 && sigLocs{vid}{ind}(peak)+floor((windSize/2)*FPSstack) < length(cDataFullTrace{vid}{ind})                
                start = sigLocs{vid}{ind}(peak)-floor((windSize/2)*FPSstack);
                stop = sigLocs{vid}{ind}(peak)+floor((windSize/2)*FPSstack);                
                if start == 0 
                    start = 1 ;
                    stop = start + floor((windSize/2)*FPSstack) + floor((windSize/2)*FPSstack);
                end                
                sortedBdata{vid}{ind}(peak,:) = bDataFullTrace{vid}(start:stop);
                sortedCdata{vid}{ind}(peak,:) = cDataFullTrace{vid}{ind}(start:stop);
                sortedVdata{vid}{ind}(peak,:) = vDataFullTrace{vid}(start:stop);
            end 
        end 
    end 
end 

%replace rows of all 0s w/NaNs
for vid = 1:length(vidList)
    for ccell = 1:length(terminals)    
        ind = find(ROIinds == terminals(ccell));
        nonZeroRowsB = all(sortedBdata{vid}{ind} == 0,2);
        sortedBdata{vid}{ind}(nonZeroRowsB,:) = NaN;
        nonZeroRowsC = all(sortedCdata{vid}{ind} == 0,2);
        sortedCdata{vid}{ind}(nonZeroRowsC,:) = NaN;
        nonZeroRowsV = all(sortedVdata{vid}{ind} == 0,2);
        sortedVdata{vid}{ind}(nonZeroRowsV,:) = NaN;
    end 
end 
%}
%% average calcium peak aligned data - normalized to number of peaks per video 
%{
% determine weights from number of peaks per video per terminal 
numPeaks = zeros(length(vidList),length(sortedCdata{1}));
for vid = 1:length(vidList)
    for ccell = 1:length(terminals)
        ind = find(ROIinds == terminals(ccell));
        numPeaks(vid,ind) = size(sortedCdata{vid}{ind},1);
    end 
end 
totalPeaks = sum(numPeaks,1);
weights = numPeaks ./ totalPeaks;

% determine weighted average and SEM- across videos - normalized by peak number  
avCweighted = cell(1,length(vidList));
avBweighted = cell(1,length(vidList));
avVweighted = cell(1,length(vidList));
semCweighted = cell(1,length(vidList));
semBweighted = cell(1,length(vidList));
semVweighted = cell(1,length(vidList));
avCweighted2 = cell(1,length(sortedCdata{1}));
avBweighted2 = cell(1,length(sortedCdata{1}));
avVweighted2 = cell(1,length(sortedCdata{1}));
semCweighted2 = cell(1,length(sortedCdata{1}));
semBweighted2 = cell(1,length(sortedCdata{1}));
semVweighted2 = cell(1,length(sortedCdata{1}));
avSortedCdata = cell(1,length(sortedCdata{1}));
avSortedBdata = cell(1,length(sortedCdata{1}));
avSortedVdata = cell(1,length(sortedCdata{1}));
semSortedCdata = cell(1,length(sortedCdata{1}));
semSortedBdata = cell(1,length(sortedCdata{1}));
semSortedVdata = cell(1,length(sortedCdata{1}));
for vid = 1:length(vidList)
    for ccell = 1:length(terminals)
        ind = find(ROIinds == terminals(ccell));
        avCweighted{vid}{ind} = nanmean((sortedCdata{vid}{ind})*weights(vid,ind),1);
        avBweighted{vid}{ind} = nanmean((sortedBdata{vid}{ind})*weights(vid,ind),1);
        avVweighted{vid}{ind} = nanmean((sortedVdata{vid}{ind})*weights(vid,ind),1);        
        semCweighted{vid}{ind} = (std(sortedCdata{vid}{ind}))/sqrt(length(sortedCdata{vid}{ind}))*weights(vid,ind);
        semBweighted{vid}{ind} = (std(sortedBdata{vid}{ind}))/sqrt(length(sortedBdata{vid}{ind}))*weights(vid,ind);
        semVweighted{vid}{ind} = (std(sortedVdata{vid}{ind}))/sqrt(length(sortedVdata{vid}{ind}))*weights(vid,ind);        
        if isempty(avCarray{vid}{ind}) == 0 
            avCweighted2{ind}(vid,:) = avCweighted{vid}{ind};
            avBweighted2{ind}(vid,:) = avBweighted{vid}{ind};
            avVweighted2{ind}(vid,:) = avVweighted{vid}{ind};
            semCweighted2{ind}(vid,:) = semCweighted{vid}{ind};
            semBweighted2{ind}(vid,:) = semBweighted{vid}{ind};
            semVweighted2{ind}(vid,:) = semVweighted{vid}{ind};
        end 
        avSortedCdata{ind} = sum(avCweighted2{ind},1);
        avSortedBdata{ind} = sum(avBweighted2{ind},1);
        avSortedVdata{ind} = sum(avVweighted2{ind},1);
        semSortedCdata{ind} = sum(semCweighted2{ind},1);
        semSortedBdata{ind} = sum(semBweighted2{ind},1);
        semSortedVdata{ind} = sum(semVweighted2{ind},1);
    end 
end 
%}
%% normalize to baseline period and plot

%normalize to baseline period 
NavCdata = cell(1,length(avSortedCdata));
NavBdata = cell(1,length(avSortedCdata));
NavVdata = cell(1,length(avSortedCdata));
NsemCdata = cell(1,length(avSortedCdata));
NsemBdata = cell(1,length(avSortedCdata));
NsemVdata = cell(1,length(avSortedCdata));
for ccell = 1:length(terminals)
    ind = find(ROIinds == terminals(ccell));
    NavCdata{ind} = ((avSortedCdata{ind}-mean(avSortedCdata{ind}(1:floor(length(avSortedCdata{ind})/3))))/mean(avSortedCdata{ind}(1:floor(length(avSortedCdata{ind})/3))))*100;
    NavBdata{ind} = ((avSortedBdata{ind}-mean(avSortedBdata{ind}(1:floor(length(avSortedBdata{ind})/3))))/mean(avSortedBdata{ind}(1:floor(length(avSortedBdata{ind})/3))))*100;
    NavVdata{ind} = ((avSortedVdata{ind}-mean(avSortedVdata{ind}(1:floor(length(avSortedVdata{ind})/3))))/mean(avSortedVdata{ind}(1:floor(length(avSortedVdata{ind})/3))))*100;    
    NsemCdata{ind} = ((semSortedCdata{ind}-mean(semSortedCdata{ind}(1:floor(length(semSortedCdata{ind})/3))))/mean(semSortedCdata{ind}(1:floor(length(semSortedCdata{ind})/3))))*100;
    NsemBdata{ind} = ((semSortedBdata{ind}-mean(semSortedBdata{ind}(1:floor(length(semSortedBdata{ind})/3))))/mean(semSortedBdata{ind}(1:floor(length(semSortedBdata{ind})/3))))*100;
    NsemVdata{ind} = ((semSortedVdata{ind}-mean(semSortedVdata{ind}(1:floor(length(semSortedVdata{ind})/3))))/mean(semSortedVdata{ind}(1:floor(length(semSortedVdata{ind})/3)))*100);
end    

%smoothing option
smoothQ = input('Input 0 to plot non-smoothed data. Input 1 to plot smoothed data.');
if smoothQ == 0 
    SNavCdata = NavCdata;
    SNavBdata = NavBdata;
    SNavVdata = NavVdata;
    SNsemCdata = NsemCdata;
    SNsemBdata = NsemBdata;
    SNsemVdata = NsemVdata;
elseif smoothQ == 1
    filtTime = input('How many seconds do you want to smooth your data by? ');
    
    SNavCdata = cell(1,length(NavCdata));
    SNavBdata = cell(1,length(NavCdata));
    SNavVdata = cell(1,length(NavCdata));
    SNsemCdata = cell(1,length(NavCdata));
    SNsemBdata = cell(1,length(NavCdata));
    SNsemVdata = cell(1,length(NavCdata));
    for ccell = 1:length(terminals)
        ind = find(ROIinds == terminals(ccell));
        [sC_Data] = MovMeanSmoothData(NavCdata{ind},filtTime,FPSstack);
        SNavCdata{ind} = sC_Data;
        [sB_Data] = MovMeanSmoothData(NavBdata{ind},filtTime,FPSstack);
        SNavBdata{ind} = sB_Data;
        [sV_Data] = MovMeanSmoothData(NavVdata{ind},filtTime,FPSstack);
        SNavVdata{ind} = sV_Data;
        [sCsem_Data] = MovMeanSmoothData(NsemCdata{ind},filtTime,FPSstack);
        SNsemCdata{ind} = sCsem_Data;
        [sBsem_Data] = MovMeanSmoothData(NsemBdata{ind},filtTime,FPSstack);
        SNsemBdata{ind} = sBsem_Data;
        [sVsem_Data] = MovMeanSmoothData(NsemVdata{ind},filtTime,FPSstack);
        SNsemVdata{ind} = sVsem_Data;
    end 
end 

%plot
for ccell = 1:length(terminals)
    ind = find(ROIinds == terminals(ccell));
    % plot 
    figure;
    Frames = length(avSortedCdata{ind});
    Frames_pre_stim_start = -((Frames-1)/2); 
    Frames_post_stim_start = (Frames-1)/2; 
    sec_TimeVals = floor(((Frames_pre_stim_start:FPSstack:Frames_post_stim_start)/FPSstack))+1;
    FrameVals = round((1:FPSstack:Frames)+5); 
    ax=gca;
    hold all
    plot(SNavCdata{ind},'b','LineWidth',2)
    plot(SNavBdata{ind},'r','LineWidth',2)
%     plot(SNavVdata{ind},'k','LineWidth',2)
    varargout = boundedline(1:size(SNavCdata{ind},2),SNavCdata{ind},SNsemCdata{ind},'b','transparency', 0.3,'alpha'); 
    varargout = boundedline(1:size(SNavBdata{ind},2),SNavBdata{ind},SNsemBdata{ind},'r','transparency', 0.3,'alpha');
%     varargout = boundedline(1:size(SNavVdata{ind},2),SNavVdata{ind},SNsemVdata{ind},'k','transparency', 0.3,'alpha');
    ax.XTick = FrameVals;
    ax.XTickLabel = sec_TimeVals;   
    ax.FontSize = 20;
    xlabel('time (s)')
    ylabel('percent change')
    xlim([0 length(SNavCdata{ind})])
    ylim([-100 500])
    legend('DA calcium','BBB data')
    if smoothQ == 0 
        title(sprintf('DA terminal #%d.',terminals(ccell)))
    elseif smoothQ == 1
        title(sprintf('DA terminal #%d. %0.2f sec smoothing.',terminals(ccell),filtTime))
    end 
end


%TO DO NEXT - MAKE BBB AND V WIDTH PLOTS SEPERATE AND SMOOTH IN ALL THE
%WAYS SORT IN ONE NOTE BEFORE CHRIS MEETING 





