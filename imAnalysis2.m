%% register images 
cd('Z:\2p\matlab');clear AVsortedData AVwheelData indices 
[regStacks,userInput,~,state_start_f,state_end_f,vel_wheel_data,TrialTypes,HDFchart] = imRegistration2(userInput);

%% set what data you want to plot 
[dataParseType] = getUserInput(userInput,'How many seconds before the stimulus starts do you want to plot?');
if dataParseType == 0 
    [sec_before_stim_start] = getUserInput(userInput,'What data do you need? Peristimulus epoch = 0. Stimulus epoch = 1.');
    [sec_after_stim_end] = getUserInput(userInput,'How many seconds after stimulus end do you want to plot?');
end 

%% set up analysis pipeline 
[VsegQ] = getUserInput(userInput,'Do you need to measure vessel width? Yes = 1. No = 0.');
[pixIntQ] = getUserInput(userInput,'Do you need to measure changes in pixel intensity? Yes = 1. No = 0.');
if pixIntQ == 1
    [CaQ] = getUserInput(userInput,'Do you need to measure changes in calcium dynamics? Yes = 1. No = 0.');
    [BBBQ] = getUserInput(userInput,'Do you need to measure changes in BBB permeability? Yes = 1. No = 0.');
end 
[cumStacksQ] = getUserInput(userInput,'Do you want to generate cumulative pixel intensity stacks? Yes = 1. No = 0.');

%% select registration method that's most appropriate for making the dff and cum pix int stacks 
[volIm] = getUserInput(userInput,'Is this volume imaging data? Yes = 1. Not = 0.');
if cumStacksQ == 1 || pixIntQ == 1 
    if volIm == 0
        regTypeDim = 0; 
    elseif volIm == 1 
        [regTypeDim] = getUserInput(userInput,'What registration dimension is best for pixel intensity analysis? 2D = 0. 3D = 1.');
    end 
    [regTypeTemp] = getUserInput(userInput,'What registration template is best for pixel intensity analysis? red = 0. green = 1.');
    [reg__Stacks] = pickRegStack(regStacks,regTypeDim,regTypeTemp);
    [reg_Stacks] = backgroundSubtraction2(reg__Stacks,BG_ROIboundData);
end
%% select registration method that's most appropriate for vessel segmentation 
if VsegQ == 1
    [regTypeDimVesSeg] = getUserInput(userInput,'What registration dimension is best for vessel segmentation? 2D = 0. 3D = 1.');
    [regTypeTempVesSeg] = getUserInput(userInput,'What registration template is best for vessel segmentation? red = 0. green = 1.');    
    [reg__StacksVesSeg] = pickRegStack(regStacks,regTypeDimVesSeg,regTypeTempVesSeg);
    [reg_Stacks] = backgroundSubtraction2(reg__StacksVesSeg,BG_ROIboundData);
end 

%% make cumulative, diff-cumulative, and DF/F stacks to output for calcium and BBB perm analysis 
%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
%EDIT-DO SLIDING BASELINE / Z-SCORING 
[FPS] = getUserInput(userInput,"FPS"); 
if cumStacksQ == 1  
    [dffDataFirst20s,CumDffDataFirst20s,CumData] = makeCumPixWholeEXPstacks(FPS,reg_Stacks);
end

%% make sure state start and end frames line up 
[numZplanes] = getUserInput(userInput,"How many Z planes are there?");
[state_start_f,state_end_f,TrialTypes] = makeSureStartEndTrialTypesLineUp(reg_Stacks,state_start_f,state_end_f,TrialTypes,numZplanes);

%% resample velocity data by trial type 
[ResampedVel_wheel_data] = resampleWheelData(reg_Stacks,vel_wheel_data);

%% get rid of frames/trials where registration gets wonky 
%EVENTUALLY MAKE THIS AUTOMATIC INSTEAD OF HAVING TO INPUT WHAT FRAME THE
%REGISTRATION GETS WONKY 
UIr = size(userInput,1)+1;
cutOffFrameQ = input('Does the registration ever get wonky? Yes = 1. No = 0. ');  userInput(UIr,1) = ("Does the registration ever get wonky? Yes = 1. No = 0."); userInput(UIr,2) = (cutOffFrameQ); UIr = UIr+1;

if cutOffFrameQ == 1 
    cutOffFrame = input('Beyond what frame is the registration wonky? ');  userInput(UIr,1) = ("Beyond what frame is the registration wonky?"); userInput(UIr,2) = (cutOffFrame); UIr = UIr+1;
    if cumStacksQ == 1 || pixIntQ == 1 
        reg___Stacks = reg_Stacks; clear reg_Stacks; 
        for zStack = 1:numZplanes
            reg_Stacks{zStack} = reg___Stacks{zStack}(:,:,1:cutOffFrame);
        end 
    end 
    
    if VsegQ == 1
        reg___StacksVesSeg = reg_Stacks; clear reg_Stacks; 
        for zStack = 1:numZplanes
            reg_Stacks{zStack} = reg___StacksVesSeg{zStack}(:,:,1:cutOffFrame);
        end 
    end 
    
    ResampedVel_wheel__data = ResampedVel_wheel_data; clear ResampedVel_wheel_data; 
    ResampedVel_wheel_data = ResampedVel_wheel__data(1:cutOffFrame);
end 


%% separate stacks by zPlane and trial type 
disp('Organizing Z-Stacks by Trial Type')
%find the diffent trial types 
[stimTimes] = getUserInput(userInput,"Stim Time Lengths (sec)"); 
[uniqueTrialData,uniqueTrialDataOcurr,indices,state_start_f] = separateTrialTypes(TrialTypes,state_start_f,state_end_f,stimTimes,numZplanes,FPS);

if volIm == 1
    %separate the Z-stacks 
    for Zstack = 1:length(reg_Stacks)
          [sorted_Stacks,indices] = eventTriggeredAverages_STACKS(reg_Stacks{Zstack},state_start_f,FPS,indices,uniqueTrialData,uniqueTrialDataOcurr,userInput,numZplanes);
          sortedStacks{Zstack} = sorted_Stacks;           
    end 
elseif volIm == 0
    %separate the Z-stacks     
      [sorted_Stacks,indices] = eventTriggeredAverages_STACKS2(reg_Stacks{1},state_start_f,FPS,indices,uniqueTrialData,uniqueTrialDataOcurr,userInput,numZplanes);
      sortedStacks{Zstack} = sorted_Stacks;           
     
end 

[sortedStacks,indices,emptyTrialTypes] = removeEmptyCells(sortedStacks,indices);

%below removes indices in cells where sortedStacks is blank 
for trialType = 1:size(sortedStacks{1},2)
    if isempty(sortedStacks{1}{trialType}) == 1 
        indices{trialType} = [];         
    end 
end 

if cumStacksQ == 1  
    [dffStacks,CumDffStacks,CumStacks] = makeCumPixStacksPerTrial(sortedStacks);
end 


%% vessel segmentation 
tic
if VsegQ == 1 
   [sortedData,userInput] = segmentVessels2(reg_Stacks,userInput,state_start_f,FPS,indices,uniqueTrialData,uniqueTrialDataOcurr,numZplanes,ROIboundData);
end 
toc
%% measure changes in calcium dynamics and BBB permeability 
if pixIntQ == 1
    if CaQ == 1
        %find max number of cells/terminals 
        maxCells = length(ROIinds);
        %determine change in pixel intensity sorted by cell identity
        %across Z 
        for cell = 1:maxCells %cell starts at 2 because that's where our cell identity labels begins (see identifyROIsAcrossZ function)
            %find the number of z planes a cell/terminal appears in 
            count = 1;
            %this figures out what planes in Z each cell occurs in (cellZ)
            for Z = 1:length(CaROImasks)                
                if ismember(ROIinds(cell),CaROImasks{Z}) == 1 
                    cellInd = max(unique(ROIorders{Z}(CaROImasks{Z} == ROIinds(cell))));
                    for frame = 1:length(reg_Stacks{Z})
                        stats = regionprops(ROIorders{Z},reg_Stacks{Z}(:,:,frame),'MeanIntensity');
                        meanPixIntArray{ROIinds(cell)}(Z,frame) = stats(cellInd).MeanIntensity;
                    end 
                end 
            end 
            %turn all rows of zeros into NaNs
            allZeroRows = find(all(meanPixIntArray{ROIinds(cell)} == 0,2));
            for row = 1:length(allZeroRows)
                meanPixIntArray{ROIinds(cell)}(allZeroRows(row),:) = NaN; 
            end 
        end 

         for cell = 1:maxCells     
                for z = 1:size(meanPixIntArray{ROIinds(cell)},1)     
                    %get median value per trace
                    dataMed = median(meanPixIntArray{ROIinds(cell)}(z,:));     
                    dataMeds{ROIinds(cell)}(z,:) = dataMed;
                    %compute DF/F using means  
                    DFOF{ROIinds(cell)}(z,:) = (meanPixIntArray{ROIinds(cell)}(z,:)-dataMeds{ROIinds(cell)}(z,:))./dataMeds{ROIinds(cell)}(z,:);                         
                    %get sliding baseline 
                    [dataSlidingBL]=slidingBaseline(DFOF{ROIinds(cell)}(z,:),floor((FPS/numZplanes)*10),0.5); %0.5 quantile thresh = the median value                 
                    dataSlidingBLs{ROIinds(cell)}(z,:) = dataSlidingBL;                       
                    %subtract sliding baseline from DF/F
                    DFOFsubSBLs{ROIinds(cell)}(z,:) = DFOF{ROIinds(cell)}(z,:)-dataSlidingBLs{ROIinds(cell)}(z,:);
                    %z-score data 
                    zData{ROIinds(cell)}(z,:) = zscore(DFOFsubSBLs{ROIinds(cell)}(z,:));
                end
         end        

        %sort calcium data by trial type 
        for cell = 1:maxCells
            for Z = 1:size(zData{ROIinds(cell)},1)                
                [sortedStatArray,indices] = eventTriggeredAverages(zData{ROIinds(cell)}(Z,:),state_start_f,FPS,indices,uniqueTrialData,uniqueTrialDataOcurr,userInput,numZplanes);            
                sortedData{ROIinds(cell)}(Z,:) = sortedStatArray;
            end                  
        end    
    end    
    if BBBQ == 1
        %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
        %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
        %PUT BBB SEGMENTATION CODE HERE 
        %MAKE THE OUTPUT HERE ALSO BE sortedData 
    end 
end 

%% wheel data work goes here 
%get median wheel value 
WdataMed = median(ResampedVel_wheel_data);     
%compute Dv/v using means  
DVOV = (ResampedVel_wheel_data-WdataMed)./WdataMed;      
%get sliding baseline 
[WdataSlidingBL]=slidingBaseline(DVOV,floor((FPS/numZplanes)*10),0.5); %0.5 quantile thresh = the median value                                   
%subtract sliding baseline from Dv/v
DVOVsubSBLs = DVOV-WdataSlidingBL;
%z-score wheel data 
zWData = zscore(DVOVsubSBLs);
%sort wheel data                    
[sortedWheelData,~] = eventTriggeredAverages(zWData,state_start_f,FPS,indices,uniqueTrialData,uniqueTrialDataOcurr,userInput,numZplanes);


%% average dff, cum dff, and cum stacks across all trials 
if cumStacksQ == 1 
    for Z = 1:numZplanes
        for trialType = 1:size(sortedData{ROIinds(2)},2) 
            for trial = 1:length(sortedWheelData{trialType})
                CumDff_Stacks{Z}{trialType}(:,:,:,trial) = CumDffStacks{Z}{trialType}{trial};
                Cum_Stacks{Z}{trialType}(:,:,:,trial) = CumStacks{Z}{trialType}{trial};
                dff_Stacks{Z}{trialType}(:,:,:,trial) = dffStacks{Z}{trialType}{trial};
                sorted_Stacks{Z}{trialType}(:,:,:,trial) = sortedStacks{Z}{trialType}{trial};
            end 
            AVcumDffStacks{Z}{trialType} = mean(CumDff_Stacks{Z}{trialType},4);
            AVcumStacks{Z}{trialType} = mean(Cum_Stacks{Z}{trialType},4);
            AVdffStacks{Z}{trialType} = mean(dff_Stacks{Z}{trialType},4);
            AVStacks{Z}{trialType} = mean(sorted_Stacks{Z}{trialType},4);        
        end 
    end 
end 
 
 %% concatenate data from previous trials 
 if pixIntQ == 1 
     for trialType = 1:size(sortedData{2},2)   
        [S, I] = sort(indices{trialType});
        indS{trialType} = S;
        indI{trialType} = I;
     end 
 elseif VsegQ == 1
     for trialType = 1:size(sortedData{2}{1},2)   
        [S, I] = sort(indices{trialType});
        indS{trialType} = S;
        indI{trialType} = I;
     end 
 end 

%sort data into correct spot for concatenation
if pixIntQ == 1 
    for cell = 1:maxCells    
        for z = 1:size(sortedData{ROIinds(cell)},1)  
            for trialType = 1:size(sortedData{ROIinds(cell)},2) %THIS IS BUGGY-NEED TO FIND EVENTUAL SOLUTION FOR - MUST WATCH DATA CAREFULLY TO MAKE SURE TRIALS AREN'T LOST 
                if ismember(uniqueTrialDataTemplate(trialType,:),uniqueTrialData,'rows') == 1
                    [~, idxStart] = ismember(uniqueTrialDataTemplate(trialType,:),uniqueTrialData,'rows');  
                    [~, idxFin] = ismember(uniqueTrialDataTemplate(trialType,:),uniqueTrialDataTemplate,'rows');
                    
                    indI2{idxFin} = indI{idxStart};
                    indices2{idxFin} = indices{idxStart};                   
                    sortedData2{ROIinds(cell)}{z,idxFin} = sortedData{ROIinds(cell)}{z,idxStart};                    
                end 
            end
        end 
    end 
    indices2 = indices2';
end 

if VsegQ == 1
    for z = 1:length(sortedData)
        for ROI = 1:size(sortedData{1},2)
            for trialType = 1:size(sortedData{1},2)        
                if ismember(uniqueTrialDataTemplate(trialType,:),uniqueTrialData,'rows') == 1
                    [~, idxStart] = ismember(uniqueTrialDataTemplate(trialType,:),uniqueTrialData,'rows');  
                    [~, idxFin] = ismember(uniqueTrialDataTemplate(trialType,:),uniqueTrialDataTemplate,'rows');
                    
                    indI2{idxFin} = indI{idxStart};
                    indices2{idxFin} = indices{idxStart};                   
                    sortedData2{z}{ROI}{idxFin} = sortedData{z}{ROI}{idxStart};                    
                end 
            end          
        end 
    end 
    indices2 = indices2';
end 

%sort wheel data into correct spot for concatenation
for trialType = 1:size(sortedData{2},2) %THIS IS BUGGY-NEED TO FIND EVENTUAL SOLUTION FOR - MUST WATCH DATA CAREFULLY TO MAKE SURE TRIALS AREN'T LOST 
    if ismember(uniqueTrialDataTemplate(trialType,:),uniqueTrialData,'rows') == 1
        [~, idxStart] = ismember(uniqueTrialDataTemplate(trialType,:),uniqueTrialData,'rows');  
        [~, idxFin] = ismember(uniqueTrialDataTemplate(trialType,:),uniqueTrialDataTemplate,'rows');
                  
        sortedWheelData2{idxFin} = sortedWheelData{idxStart};                    
    end     
end

if pixIntQ == 1  
    %reorganize data by trial order 
     for cell = 1:maxCells
        for z = 1:size(sortedData2{ROIinds(cell)},1)
            for trialType = 1:size(indices2,1)
                if isempty(sortedData2{ROIinds(cell)}{z,trialType}) == 0
                    dataToPlot2{ROIinds(cell)}{z,trialType} = sortedData2{ROIinds(cell)}{z,trialType}(indI2{trialType});       
                end 
            end 
        end 
     end 
end 

if VsegQ == 1
    %reorganize data by trial order 
    for z = 1:length(sortedData)
        for ROI = 1:size(sortedData{1},2)
            for trialType = 1:size(indices2,1)
                if isempty(sortedData2{z}{ROI}{trialType}) == 0
                    dataToPlot2{z}{ROI}{trialType} = sortedData2{z}{ROI}{trialType}(indI2{trialType});       
                end 
            end 
        end 
     end 
end 


for trialType = 1:size(indices2,1)
    if isempty(sortedWheelData2{trialType}) == 0 
        wheelDataToPlot2{trialType} = sortedWheelData2{trialType}(indI2{trialType});     
    end
end 

if pixIntQ == 1 
    [dataToPlot3] = catData(dataToPlot,dataToPlot2,maxCells,ROIinds);
end 

if VsegQ == 1
    if size(dataToPlot2{1}{1},2) < size(dataToPlot{1}{1},2)
        ind1 = size(dataToPlot2{1}{1},2) + 1; ind2 = size(dataToPlot{1}{1},2);
        for z = 1:length(dataToPlot)
            for ROI = 1:size(dataToPlot{1},2)
                dataToPlot2{z}{ROI}{ind1:ind2} = [];
            end 
        end 
    end 
    
    [dataToPlot3] = catData2(dataToPlot,dataToPlot2);
end 

[wheelDataToPlot3] = catWheelData(wheelDataToPlot,wheelDataToPlot2);

%% prep data for plotting - get rid of what you don't need and average 
dataToPlot = dataToPlot3;
wheelDataToPlot = wheelDataToPlot3; 

clear dataToPlot3 wheelDataToPlot3

if pixIntQ == 1    
    for cell = 1:maxCells  
        for z = 1:size(dataToPlot{ROIinds(cell)},1)
            for trialType = 1:size(dataToPlot{ROIinds(cell)},2) 
                if isempty(dataToPlot{ROIinds(cell)}{z,trialType}) == 0 
                    reshapedArray = cat(3,dataToPlot{ROIinds(cell)}{z,trialType}{:});
                    AV = nanmean(reshapedArray,3);
                    AVsortedData{ROIinds(cell)}{z,trialType}(1,:) = AV; 
                end 
            end 
        end 
    end        
end 

if VsegQ == 1   
    for z = 1:length(sortedData)
        for ROI = 1:size(sortedData{1},2)
            for trialType = 1:size(dataToPlot{1}{1},2) 
                 if isempty(dataToPlot{z}{ROI}{trialType}) == 0 
                    reshapedArray = cat(3,dataToPlot{z}{ROI}{trialType}{:});
                    AV = nanmean(reshapedArray,3);
                    AVsortedData{z}{ROI}{trialType}(1,:) = AV; 
                 end 
 
            end 
        end 
    end      
    maxCells = size(sortedData{1},2);
end 

for trialType = 1:length(wheelDataToPlot)
    if isempty(wheelDataToPlot{trialType}) == 0 
        reshapedArray = cat(3,wheelDataToPlot{trialType}{:});
        AV = nanmean(reshapedArray,3);
        AVwheelData{trialType}(1,:) = AV;  
    end 
end 
 
%clearvars -except dataToPlot AVsortedData wheelDataToPlot AVwheelData userInput FPS sec_before_stim_start dataMin dataMax velMin velMax HDFchart numZplanes BG_ROIboundData CaROImasks uniqueTrialDataTemplate CaROImasks maxCells ROIorders ROIinds ROIboundData


 %% Filter the data (Gaussian Filter)
 %REPLACE WITH FREQUENCY FILTERING 
 %{
% time_to_filter_by = input("How much time do you want to filter the data by? ");
% filter_rate = FPS*time_to_filter_by; 
% 
% if ismember(1,TrialTypes(:,2)) == 1
%     [T1DataNF] = filter_F_data(T1DataN,filter_rate);
%     [T1velDataF] = filter_F_data(T1velData,filter_rate);
% end
% 
% if ismember(2,TrialTypes(:,2)) == 1
%     [T2DataNF] = filter_F_data(T2DataN,filter_rate);
%     [T2velDataF] = filter_F_data(T2velData,filter_rate);
% end 
% 
% if ismember(3,TrialTypes(:,2)) == 1
%     [T3DataNF] = filter_F_data(T3DataN,filter_rate);
%     [T3velDataF] = filter_F_data(T3velData,filter_rate);
% end
%}
 

%% plot 
dataMin = input("data Y axis MIN: ");
dataMax = input("data Y axis MAX: ");
velMin = input("running velocity Y axis MIN: ");
velMax = input("running velocity Y axis MAX: ");


%plotDataAndRunVelocity(dataToPlot,AVsortedData,wheelDataToPlot,AVwheelData,FPS,numZplanes,sec_before_stim_start,dataMin,dataMax,velMin,velMax,maxCells,ROIinds)
plotAVDataAndRunVelocity(VdataToPlot,VAVsortedData,dataToPlot,AVsortedData,wheelDataToPlot,AVwheelData,FPS,numZplanes,sec_before_stim_start,dataMin,dataMax,velMin,velMax,maxCells,ROIinds)
%plotAVtTypeDataAndRunVelocity(VdataToPlot,VAVsortedData,AVtType1,AVtType2,AVtType3,AVtType4,AVAVtType1,AVAVtType2,AVAVtType3,AVAVtType4,wheelDataToPlot,AVwheelData,FPS,numZplanes,sec_before_stim_start,dataMin,dataMax,velMin,velMax,maxCells,ROIinds)
%plotAllAVDataAndRunVelocity(VdataToPlot,VAVsortedData,allAVarray,allAV,wheelDataToPlot,AVwheelData,FPS,numZplanes,sec_before_stim_start,dataMin,dataMax,velMin,velMax,maxCells,ROIinds)

%% in case the V data array is missing some trial type data and it needs to be the same size as the calcium data array for plotting 

for z = 1:length(VAVsortedData)
        for ROI = 1:size(VAVsortedData{z},2)
            for trialType = 1:size(AVsortedData{2},2)
                if size(VAVsortedData{z}{ROI},2) < trialType
                    for frame = 1:635
                        %VAVsortedData{z}{ROI}{trialType}(1,frame) = NaN; 
                        SEMVdata{z}{ROI}{trialType}(1,frame) = NaN;
                    end 
                    
                end 
            end 
        end 
end 

% 
%% average by trial types  
[AVsortedData2] = makeCellArrayCellsSameSize(AVsortedData,maxCells,ROIinds);

%average all trial types across all ROIs (calcium data) 
terminals = [15,13,11,10,2,3];

for cell = 1:length(terminals)  
    for z = 1%:3        
        tType1(z,:,cell) = AVsortedData2{terminals(cell)}{z,1}; 
%         tType2(z,:,cell) = AVsortedData2{ROIinds(cell)}{z,2}; 
%         tType3(z,:,cell) = AVsortedData2{ROIinds(cell)}{z,3}; 
        %tType4(z,:,cell) = AVsortedData2{ROIinds(cell)}{z,4}; 
    end 
 end 

% for cell = 1:maxCells  
%     for z = 1%:3        
%         tType1(z,:,cell) = AVsortedData2{ROIinds(cell)}{z,1}; 
% %         tType2(z,:,cell) = AVsortedData2{ROIinds(cell)}{z,2}; 
% %         tType3(z,:,cell) = AVsortedData2{ROIinds(cell)}{z,3}; 
%         %tType4(z,:,cell) = AVsortedData2{ROIinds(cell)}{z,4}; 
%     end 
%  end 
 
AVtType1 = nanmean(tType1,3); 
AVtType2 = nanmean(tType2,3);  
AVtType3 = nanmean(tType3,3); 
%AVtType4 = nanmean(tType4,3); 

AVAVtType1 = nanmean(AVtType1,1); 
AVAVtType2 = nanmean(AVtType2,1);  
AVAVtType3 = nanmean(AVtType3,1); 
%AVAVtType4 = nanmean(AVtType4,1); 



allAVarray(1,:) = AVAVtType1; %allAVarray(2,:) = AVAVtType2(1,1:size(AVsortedData{2}{1,1},2)); allAVarray(3,:) = AVAVtType3; %allAVarray(4,:) = AVAVtType4(1,1:size(AVsortedData{2}{1,1},2));
allAV = mean(allAVarray,1);

%per terminal - average all the trials 

cellAVtType1 = nanmean(tType1,1);
cellAVtType2 = nanmean(tType2,1);
cellAVtType3 = nanmean(tType3,1);
%cellAVtType4 = nanmean(tType4,1);

cellAllAv(1,:,:) = cellAVtType1; %cellAllAv(2,:,:) = cellAVtType2(:,1:size(AVsortedData{2}{1,1},2),:); cellAllAv(3,:,:) = cellAVtType3;%cellAllAv(4,:,:) = cellAVtType4(:,1:size(AVsortedData{2}{1,1},2),:);
cellAllAvRed(1,:,:) = cellAVtType3;%cellAllAvRed(2,:,:) = cellAVtType4(:,1:size(AVsortedData{2}{1,1},2),:);
cellAllAvBlue(1,:,:) = cellAVtType1;cellAllAvBlue(2,:,:) = cellAVtType2(:,1:size(AVsortedData{2}{1,1},2),:);

cellAllAvAV = nanmean(cellAllAv,1);
cellAllAvAVred = nanmean(cellAllAvRed,1);
cellAllAvAVblue = nanmean(cellAllAvBlue,1);

ALLRED = nanmean(cellAllAvAVred,3);
ALLBLUE = nanmean(cellAllAvAVblue,3);

%separate vessel width data by trial type - red vs blue 
%average all trial types across all ROIs (calcium data) 
V = 1;
redV(1,:) = VAVsortedData{1}{V}{3}; redV(2,:) = VAVsortedData{2}{V}{3}; redV(3,:) = VAVsortedData{3}{V}{3};
%redV(4,:) = VAVsortedData{1}{V}{4}(1,1:size(AVsortedData{2}{1,1},2)); redV(5,:) = VAVsortedData{2}{V}{4}(1,1:size(AVsortedData{2}{1,1},2)); redV(6,:) = VAVsortedData{3}{V}{4}(1,1:size(AVsortedData{2}{1,1},2));

V = 2;
blueV(1,:) = VAVsortedData{1}{V}{1}; blueV(2,:) = VAVsortedData{2}{V}{1}; blueV(3,:) = VAVsortedData{3}{V}{1};
blueV(4,:) = VAVsortedData{1}{V}{2}(1,1:size(AVsortedData{2}{1,1},2)); blueV(5,:) = VAVsortedData{2}{V}{2}(1,1:size(AVsortedData{2}{1,1},2)); blueV(6,:) = VAVsortedData{3}{V}{2}(1,1:size(AVsortedData{2}{1,1},2));


redVAV = nanmean(redV,1);
blueVAV = nanmean(blueV,1);

allVAVarray(1,:) = redVAV ; allVAVarray(2,:) = blueVAV;
allVAV = nanmean(allVAVarray,1);

for trial = 1:length(VdataToPlot{1}{1}{1})
    VDataArray(:,:,trial) =VdataToPlot{1}{V}{1}{trial};
end 

%average wheel data: RED, BLUE, and REDBLUE 
redW(1,:) = AVwheelData{3}; %redW(2,:) = AVwheelData{4}(1:size(AVwheelData{1},2));
blueW(1,:) = AVwheelData{1}; blueW(2,:) = AVwheelData{2}(1:size(AVwheelData{1},2));

AVredW = nanmean(redW,1);
AVblueW = nanmean(blueW,1);

AllW(1,:) = AVredW; AllW(2,:) = AVblueW;
AVallW = nanmean(AllW,1);

for trial = 1:length(wheelDataToPlot{1})
    wheelDataArray(:,:,trial) = wheelDataToPlot{1}{trial};
end 

%}