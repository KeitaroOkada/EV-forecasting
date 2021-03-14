% ---------------------------------------------------------------------------
% EV demand forecast: Prediction Model development algorithm 
% 10th June, 2020 Updated by Daisuke Kodaira 
% daisuke.kodaira03@gmail.com
% 
% function flag =setEVModel(LongTermPastData)
%         flag =1 ; if operation is completed successfully
%         flag = -1; if operation fails.
% ----------------------------------------------------------------------------

function setEVModel(LongTermPastData)
    tic;
    warning('off','all');   % Warning is not shown
    
    %% Get file path
    path = fileparts(LongTermPastData);     
    
    %% Load data
    if strcmp(LongTermPastData, 'NULL') == 0    % if the filename is not null
        AllPastData = readtable(LongTermPastData);
    else  % if the fine name is null
        flag = -1;  % return error
        return
    end 
    
    %% Devide the data into training and validation
    % Parameter
    ValidDays = 30; % it must be above 1 day. 3days might provide the best performance
    nValidData = 96*ValidDays; % 24*4*day   valid_data = longPast(end-n_valid_data+1:end, :); 
    colPredictors = {'BuildingIndex', 'Year', 'Month', 'Day', 'Hour', 'Quarter', 'DayInWeek', 'HolidayOrNot'};
        
    % Divide all past data into training and validation
    % For validation
    trainData = AllPastData(1:end-nValidData, :);     % training Data (predictors + target)
    validData.Predictor = AllPastData(end-nValidData+1:end, colPredictors);    % validation Data (predictors only)
    validData.TargetEnergy = table2array(AllPastData(end-nValidData+1:end, {'ChargeDischargeKwh'})); % trarget Data for validation (targets only)
    validData.TargetSOC = table2array(AllPastData(end-nValidData+1:end, {'SOCPercent'})); % trarget Data for validation (targets only)
    % For all data
    allData.Predictor = AllPastData(:, colPredictors);    % validation Data (predictors only)
    allData.TargetEnergy = table2array(AllPastData(:, {'ChargeDischargeKwh'})); % trarget Data for validation (targets only)
    allData.TargetSOC = table2array(AllPastData(:, {'SOCPercent'})); % trarget Data for validation (targets only)
        
    %% Train each model using past load data
    kmeansEV_Training(trainData, colPredictors, path);
    neuralNetEV_Training(trainData, colPredictors, path);
    %     LSTMEV_Training();    % add LSTM here later
    
    %% Validate the performance of each model
    % Note: return shouldn't be located inside of structure. It should be sotred as matrix.
    %           This is because it makes problem after .m files is converted into java files 
    % 1. for validation data
    [validData.PredEnergy(:,1), validData.PredSOC(:,1)]  = kmeansEV_Forecast(validData.Predictor, path);
    [validData.PredEnergy(:,2), validData.PredSOC(:,2)] = neuralNetEV_Forecast(validData.Predictor, path); 
    %     [PredEnergyTrans_Valid(:,3), PredSOC_Valid(:,3)] = LSTMEV_Forecast(validData, path); % add LSTM here later
    % 2. for all past data
    [allData.PredEnergy(:,1), allData.PredSOC(:,1)]  = kmeansEV_Forecast(allData.Predictor, path);
    [allData.PredEnergy(:,2), allData.PredSOC(:,2)] = neuralNetEV_Forecast(allData.Predictor, path); 
    
    %% Optimize the coefficients (weights) for the ensembled forecasting model
    weight.Energy = getWeight(validData.Predictor, validData.PredEnergy, validData.TargetEnergy);
    weight.SOC = getWeight(validData.Predictor, validData.PredSOC, validData.TargetSOC);
        
    %% Get error distribution
    % 1. Get error distribution for validation data (validation is not included traing process)
    [errDist.EnergyValid, errDist.SOCValid] = getErrorDist(validData, weight);
    % 2. Get error distribution for validation data (validation is not included traing process)    
    [errDist.EnergyAll, errDist.SOCAll] = getErrorDist(allData, weight);
      
        
    %% Save .mat files
    filename = {'EV_weight_'; 'EV_errDist_'};
    Bnumber = num2str(AllPastData.BuildingIndex(1)); % Get building index to add to fine name
    varX = {'weight'; 'errDist'};
    for i = 1:size(varX,1)
        name = strcat(filename(i), Bnumber, '.mat');
        matname = fullfile(path, name);
        save(char(matname), char(varX(i)));
    end
    
%     % for debugging --------------------------------------------------------
%     % Under construction 2020 June 16th
%         display_result(1:size(nValidData,1), ensembledPredEnergy, validData.TargetEnergy, [], 'EnergyTrans'); % EnergyTrans
%         display_result(1:size(nValidData,1), ensembledPredSOC, validData.TargetSOC, [], 'SOC'); % SOC 
%     % for debugging --------------------------------------------------------------------- 
    
    toc;
end
