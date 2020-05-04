% function [TSdataBBBperm] = calciumTSwholeExp(regStacks,userInput)
%% get just the data you need 
temp1 = matfile('SF56_20190718_ROI2_8_regIms_green.mat');
regStacks = temp1.regStacks;
numZplanes = temp1.numZplanes ;

temp2 = matfile('SF56_20190718_ROI2_1-3_5_7_VW_and_1-5_7_10CaData.mat');
userInput = temp2.userInput; 
CaROImasks = temp2.CaROImasks; 
ROIorders = temp2.ROIorders; 

%% do background subtraction 
input_Stacks = regStacks{2,3};
[inputStacks,BG_ROIboundData] = backgroundSubtraction(input_Stacks);

%% get rid of frames/trials where registration gets wonky 
%EVENTUALLY MAKE THIS AUTOMATIC INSTEAD OF HAVING TO INPUT WHAT FRAME THE
%REGISTRATION GETS WONKY 
cutOffFrameQ = input('Does the registration ever get wonky? Yes = 1. No = 0. '); 
if cutOffFrameQ == 1 
    cutOffFrame = input('Beyond what frame is the registration wonky? ');  
    Ims = cell(1,length(inputStacks));
    for Z = 1:length(inputStacks)
        Ims{Z} = inputStacks{Z}(:,:,1:cutOffFrame);  
    end 
elseif cutOffFrameQ == 0 
    Ims = inputStacks;
end 

clear inputStacks
%% apply CaROImask and process data 

%determine the indices left for the edited CaROImasks or else
%there will be indexing problems below through iteration 
ROIinds = unique([CaROImasks{:}]);
%remove zero
ROIinds(ROIinds==0) = [];
%find max number of cells/terminals 
maxCells = length(ROIinds);

meanPixIntArray = cell(1,ROIinds(maxCells));
for ccell = 1:maxCells %cell starts at 2 because that's where our cell identity labels begins (see identifyROIsAcrossZ function)
    %find the number of z planes a cell/terminal appears in 
    %this figures out what planes in Z each cell occurs in (cellZ)
    for Z = 1:length(CaROImasks)                
        if ismember(ROIinds(ccell),CaROImasks{Z}) == 1 
            cellInd = max(unique(ROIorders{Z}(CaROImasks{Z} == ROIinds(ccell))));
            for frame = 1:length(Ims{Z})
                stats = regionprops(ROIorders{Z},Ims{Z}(:,:,frame),'MeanIntensity');
                meanPixIntArray{ROIinds(ccell)}(Z,frame) = stats(cellInd).MeanIntensity;
            end 
        end 
    end 
    %turn all rows of zeros into NaNs
    allZeroRows = find(all(meanPixIntArray{ROIinds(ccell)} == 0,2));
    for row = 1:length(allZeroRows)
        meanPixIntArray{ROIinds(ccell)}(allZeroRows(row),:) = NaN; 
    end 
end 

[FPS] = getUserInput(userInput,"FPS"); 
%  dataMeds = cell(1,ROIinds(maxCells));
%  DFOF = cell(1,ROIinds(maxCells));
 dataSlidingBLs = cell(1,ROIinds(maxCells));
FsubSBLs = cell(1,ROIinds(maxCells));
%  zData = cell(1,length(ROIinds));
%  count = 1;
 for ccell = 1:maxCells     
        for z = 1:size(meanPixIntArray{ROIinds(ccell)},1)     
%             %get median value per trace
%             dataMed = median(meanPixIntArray{ROIinds(ccell)}(z,:));     
%             dataMeds{ROIinds(ccell)}(z,:) = dataMed;
%             %compute DF/F using means  
%             DFOF{ROIinds(ccell)}(z,:) = (meanPixIntArray{ROIinds(ccell)}(z,:)-dataMeds{ROIinds(ccell)}(z,:))./dataMeds{ROIinds(ccell)}(z,:);                         
            %get sliding baseline 
%             [dataSlidingBL]=slidingBaseline(DFOF{ROIinds(ccell)}(z,:),floor((FPS/numZplanes)*10),0.5); %0.5 quantile thresh = the median value      
            [dataSlidingBL]=slidingBaseline(meanPixIntArray{ROIinds(ccell)}(z,:),floor((FPS/numZplanes)*10),0.5); %0.5 quantile thresh = the median value
            dataSlidingBLs{ROIinds(ccell)}(z,:) = dataSlidingBL;                       
%             %subtract sliding baseline from DF/F
%             DFOFsubSBLs{ROIinds(ccell)}(z,:) = DFOF{ROIinds(ccell)}(z,:)-dataSlidingBLs{ROIinds(ccell)}(z,:);
            %subtract sliding baseline from F trace 
            FsubSBLs{ROIinds(ccell)}(z,:) = meanPixIntArray{ROIinds(ccell)}(z,:)-dataSlidingBLs{ROIinds(ccell)}(z,:);

            %z-score data 
%             zData{ROIinds(ccell)}(z,:) = zscore(DFOFsubSBLs{ROIinds(ccell)}(z,:));
        end
%         count = count + 1 ;
 end        

%% average across z and cells 
%  zData2 = cell(1,length(zData));
%  zData2array = zeros(length(zData),size(zData{1},2));
meanPixIntArray2 = cell(1,length(meanPixIntArray));
meanPixIntArray3 = zeros(length(meanPixIntArray),size(meanPixIntArray{2},2));
dataSlidingBLs2 = cell(1,length(meanPixIntArray));
dataSlidingBLs3 = zeros(length(meanPixIntArray),size(meanPixIntArray{2},2));
FsubSBLs2 = cell(1,length(meanPixIntArray));
FsubSBLs3 = zeros(length(meanPixIntArray),size(meanPixIntArray{2},2));
 for ccell = 1:maxCells
%      zData2{ROIinds(ccell)} = nanmean(zData{ROIinds(ccell)},1);
%      zData2array(ROIinds(ccell),:) = zData2{ROIinds(ccell)};
       meanPixIntArray2{ROIinds(ccell)} = nanmean(meanPixIntArray{ROIinds(ccell)},1);
       meanPixIntArray3(ROIinds(ccell),:) = meanPixIntArray2{ROIinds(ccell)};
       dataSlidingBLs2{ROIinds(ccell)} = nanmean(dataSlidingBLs{ROIinds(ccell)},1);
       dataSlidingBLs3(ROIinds(ccell),:) = dataSlidingBLs2{ROIinds(ccell)};
       FsubSBLs2{ROIinds(ccell)} = nanmean(FsubSBLs{ROIinds(ccell)},1);
       FsubSBLs3(ROIinds(ccell),:) = FsubSBLs2{ROIinds(ccell)};
 end 
%  Cdata = nanmean(zData2array,1);
%  CcellData = zData2; 
Fdata = nanmean(meanPixIntArray3,1);
slidingBL = nanmean(dataSlidingBLs3,1);
FsubBLdata = nanmean(FsubSBLs3,1);

avFdata = Fdata;
terminalFData = meanPixIntArray2;

avFsubSB = FsubBLdata; 
terminalFsubSB = FsubSBLs2;
 
 
 %% PLAYGROUND 
Cdata = avFsubSB; CcellData = terminalFsubSB;
 
plot(Cdata)
 
clearvars -except Cdata CcellData FPS CaROImasks userInput avFdata terminalFData avFsubSB terminalFsubSB numZplanes
 
%  Cdata = Cdata(1:1186);
 
% inputStacks = (Ims{1} + Ims{2} + Ims{3})/3;

% inputStacks = Ims{1};

% end 