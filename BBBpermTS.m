function [TSdataBBBperm] = BBBpermTS(inputStacks,userInput)

% inputStacks = sortedStacks; DELETE WHEN DONE TROUBLESHOOTING 


%% create non-vascular ROI for entire x-y plane 

%go to dir w/functions
[imAn1funcDir] = getUserInput(userInput,'imAnalysis1_functions Directory');
cd(imAn1funcDir); 

%update userInput 
UIr = size(userInput,1)+1;
numROIs = input("How many BBB perm ROIs are we making? "); userInput(UIr,1) = ("How many BBB perm ROIs are we making?"); userInput(UIr,2) = (numROIs); UIr = UIr+1;

%for display purposes mostly: average across trials 
inputStacks4D = cell(1,length(inputStacks));
stackAVs = cell(1,length(inputStacks));
stackAVsIm = cell(1,length(inputStacks));
for z = 1:length(inputStacks)
    for trialType = 1:size(inputStacks{z},2)
        if isempty(inputStacks{z}{trialType}) == 0 
            for trial = 1:size(inputStacks{z}{trialType},2)
                inputStacks4D{z}{trialType}(:,:,:,trial) = inputStacks{z}{trialType}{trial};
            end 
            stackAVs{z}{trialType} = mean(inputStacks4D{z}{trialType},4);
            stackAVsIm{z}{trialType} = mean(stackAVs{z}{trialType},3);
        end  
    end 
end 

ROIboundDatas = cell(1,length(inputStacks));
ROIstacks = cell(1,length(inputStacks));
for z = 1:length(inputStacks)
    ROIboundQ = 1; 
    for trialType = 1:size(inputStacks{z},2)
        if isempty(inputStacks{z}{trialType}) == 0 
            %create the ROI boundaries 
            if ROIboundQ == 1           
                for VROI = 1:numROIs 
                    disp('Create your ROI for vessel segmentation');

                    [~,xmins,ymins,widths,heights] = firstTimeCreateROIs(1, stackAVsIm{z}{trialType});
                    ROIboundData{1} = xmins;
                    ROIboundData{2} = ymins;
                    ROIboundData{3} = widths;
                    ROIboundData{4} = heights;

                    ROIboundDatas{z}{VROI} = ROIboundData;
                end 
                ROIboundQ = 0; 
            end 
            
            %use the ROI boundaries to generate ROIstacks 
            for trial = 1:size(inputStacks{z}{trialType},2)
                for VROI = 1:numROIs 
                    xmins = ROIboundDatas{z}{VROI}{1};
                    ymins = ROIboundDatas{z}{VROI}{2};
                    widths = ROIboundDatas{z}{VROI}{3};
                    heights = ROIboundDatas{z}{VROI}{4};
                    [ROI_stacks] = make_ROIs_notfirst_time(inputStacks{z}{trialType}{trial},xmins,ymins,widths,heights);
                    ROIstacks{z}{trialType}{trial}{VROI} = ROI_stacks;
                end 
            end 
        end 
    end 
end 
                    
                    
 



%@@@@@@@@@@@@@@@@@@@CREATE ROI FIRST AND THEN SEGMENT IMAGE 





















































threshQ = 1; 


while threshQ == 1 
    imThresh = input('Set the non-vascular ROI generation pixel intensity threshold. (Try ~0.04) '); 
    %scale the images to be between 0 to 1 
    scaledIm = inputStacks{1}{1}{1}(:,:,1) ./ max(inputStacks{1}{1}{1}(:,:,1));
    %apply a threshold to create mask 
    nm1BW = imbinarize(scaledIm,imThresh);
    %invert the mask 
    nm1BW2 = ~nm1BW;    
    %Open mask with disk
    radius = 1;
    decomposition = 0;
    se = strel('disk', radius, decomposition);
    nm1BW3 = imopen(nm1BW2, se);
        %fill holes 
    nm1BW4 = imfill(nm1BW3, 'holes');                       
        %erode mask with disk
    radius = 2;
    decomposition = 0;
    se = strel('disk', radius, decomposition);
    nm1BW5 = imerode(nm1BW4, se);
         %dilate mask with disk
    radius = 3;
    decomposition = 0;
    se = strel('disk', radius, decomposition);
    nm1BW6 = imdilate(nm1BW5, se);
    
         %active contour using edge over 2 iterations
    iterations = 1000;
    nm1BW7 = activecontour(nm1BW6, nm1BW6, iterations, 'edge');
    
    nm1BW_perim = bwperim(nm1BW7);
    %show the overlay 
    avIm = mean(inputStacks{1}{1}{1},3);
    scaledAvIm = avIm ./ max(avIm);
    BBB_ROIs = imoverlay(scaledAvIm, nm1BW_perim, [.3 1 .3]);% | maskEm, [.3 1 .3]);

    figure;imshow(BBB_ROIs); 
    
    threshQ = input('Change pixel intensity threshold? Yes = 1. No = 0. ');    
end 

if threshQ == 0 
    %PUT THE ITERATIVE LOOP BELOW HERE!! 
end 



%--------------------------------------------NEED TO SHOW EXAMPLE IMAGE OF
%SEGMENTATION ABOVE AND THEN ITERATE THROUGH ALL FRAMES BELOW - THIS GOES
%IN THE IF STATEMENT ABOVE 
for z = 1:length(inputStacks)
    for trialType = 1%:length(inputStacks{z}) 
        if isempty(inputStacks{z}{trialType}) == 0  
            for trial = 1%:size(inputStacks{z}{trialType},2)
                for frame = 1:size(inputStacks{z}{trialType}{trial},3)
                     
                    %scale the images to be between 0 to 1 
                    scaledStacks{z}{trialType}{trial}(:,:,frame) = inputStacks{z}{trialType}{trial}(:,:,frame) ./ max(inputStacks{z}{trialType}{trial}(:,:,frame));

                    CAroiGen = 1;
                    while CAroiGen == 1              
                        
                        %apply a threshold to create mask 
                        nm1BW = imbinarize(scaledStacks{z}{trialType}{trial}(:,:,frame),imThresh);
                        %invert the mask 
                        nm1BW2 = ~nm1BW;    
                        %clean the mask up 
                            %Open mask with disk
                        radius = 1;
                        decomposition = 0;
                        se = strel('disk', radius, decomposition);
                        nm1BW3 = imopen(nm1BW2, se);
                            %fill holes 
                        nm1BW4 = imfill(nm1BW3, 'holes');                       
                            %erode mask with disk
                        radius = 2;
                        decomposition = 0;
                        se = strel('disk', radius, decomposition);
                        nm1BW5 = imerode(nm1BW4, se);
                        %sort masks 
                        nm1BW_perim{z}{trialType}{trial}(:,:,frame) = bwperim(nm1BW5);

                        %BBB_ROIs = imoverlay(stackAVs{trialType}, nm1BW2_perim, [.3 1 .3]);% | maskEm, [.3 1 .3]);
                    end 

                %ABOVE IS WORKING CODE - ADD IN CODE TO PLAY THE MASK OVER THE ORIGINAL STACK AS DONE WITH
%                 %VESSEL SEGMENTATION 
% 
%                 %check segmentation 
%                 setMaxPoint = 1;
%                 while setMaxPoint == 1 
%                     maxPoint = input("What should the pixel max point be to visualize mask boundaries? ");
%                     framesToShow = 200;
%                     if volIm == 1
%                         Zplane = input('What Z plane do you want to see?');
%                     elseif volIm == 0
%                         Zplane = 1;
%                     end 
%                     for VROI = 1:numROIs
%                         play_mask_over_roi_stack(ROIstacks{Zplane}{VROI}{1},boundaries{Zplane}{VROI},framesToShow,maxPoint);
%                     end 
%                     setMaxPoint = input("Do you need to reset the pixel max point? Yes = 1. No = 0. "); 
%                 end 
% 
%                 segmentVessel = input("Does the vessel need to be segmented again? Yes = 1. No = 0. ");
%                 if segmentVessel == 1
%                     clear BWthreshold BWopenRadius BW se boundaries
%                 end 
% % 
%               %--------------------------------------------------          
% 
%                 %ABOVE IS WORKING CODE - TROUBLESHOOTING BELOW             
% 
%                     CAroiGen = input('Do the calcium ROIs need to be redone? Yes = 1. No = 0. ');
%                     if CAroiGen == 1 
%                         clear CaROIs 
%                     elseif CAroiGen == 0
%                         userInput(UIr,1) = (sprintf("Set the calcium ROI generation pixel intensity threshold. Z%d",Z)); userInput(UIr,2) = (imThresh); UIr = UIr+1;
%                     end 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 

%                     CaROImasks{trialType} = nm1BW2; 

                %     %figure out the order that terminal ROIs are looked at to match ROI
                %     %with data 
                %     ROIorders{trialType} = bwlabel(nm1BW2);
                end 
            end 
        end 
    end
end

%save('Last2019Dayta');


end 