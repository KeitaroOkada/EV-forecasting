% ---------------------------------------------------------------------------
% EV prediction: Foecasting algorithm 
% 6th March,2019 Updated by Daisuke Kodaira 
% Contact: daisuke.kodaira03@gmail.com
%
% function flag = demandForecast(shortTermPastData, ForecastData, ResultData)
%     flag =1 ; if operation is completed successfully
%     flag = -1; if operation fails.
%     This function depends on demandModel.mat. If these files are not found return -1.
%     The output of the function is "ResultData.csv"
% ----------------------------------------------------------------------------

function flag = getEVModel(shortTermPastData, forecastData, resultFilePath)
    tic;
    
    %% Error check and Load input datathe 
    if (strcmp(shortTermPastData, 'NULL') == 0) && (strcmp(forecastData, 'NULL') == 0)
        % if the filename is exsit
        shortTerm = readtable(shortTermPastData);
        predData.predictors = readtable(forecastData);
    else
        % if the file name doesn't exsit
        flag = -1;  % return error
        return
    end   
    
    % parameters
    buildingIndex = shortTerm.BuildingIndex(1);
    ci_percentage = 0.05; % 0.05 = 95% it must be between 0 to 1
    
    %% Load .mat files from give path of "shortTermPastData"
    path = fileparts(shortTermPastData);

    %% Error recognition: Check mat files exist
    name1 = [path, '\', 'EV_trainedKmeans_', num2str(buildingIndex), '.mat'];
    name2 = [path, '\', 'EV_trainedNeuralNet_', num2str(buildingIndex), '.mat'];
    name3 = [path, '\', 'EV_errDist_', num2str(buildingIndex), '.mat'];
    name4 = [path, '\', 'EV_weight_', num2str(buildingIndex), '.mat'];
    if exist(name1) == 0 || exist(name2) == 0 || exist(name3) == 0 || exist(name4) == 0
        flag = -1;
        return
    end
    
    %% Load mat files
    s(1).fname = 'EV_trainedKmeans_';
    s(2).fname = 'EV_trainedNeuralNet_';
    s(3).fname = 'EV_errDist_';
    s(4).fname = 'EV_weight_';
    s(5).fname = num2str(buildingIndex);    
    extention='.mat';
    for i = 1:size(s,2)-1
        name(i).string = strcat(s(i).fname, s(end).fname);
        matname = fullfile(path, [name(i).string extention]);
        load(matname);
    end
    
    %% Get individual prediction for test data
    % Two methods are combined
    %   1. k-menas
    %   2. Neural network
    [predData.IndEnergy(:,1), predData.IndSOC(:,1)]  = kmeansEV_Forecast(predData.predictors, path);
    [predData.IndEnergy(:,2), predData.IndSOC(:,2)] = neuralNetEV_Forecast(predData.predictors, path);  
    
    %% Get combined prediction result with weight for each algorithm
    records = size(predData.Energy, 1);
    
    % Prepare the tables to store the deterministic forecasted result (ensemble forecasted result)
    % Note: the forecasted results are stored in an hourly basis
    predData.EnsembleEnergy = nan(1:24, 1);
    predData.EnsembleSOC = nan(1:24, 1);

    for i = 1:records
        hour = predData.predictors.Hour(i)+1;   % transpose Hour from 0~23 to 1~24
        if isnan(predData.EnsembleEnergy(hour,1))
            % the data is not stored for the hour yet
            predData.EnsembleEnergy(hour,) = weightEnergy.*predData.Energy(i, :);
            predData.SOC(hour,) = weightSOC.*predData.SOC(i, :);
        else
            predData.EnsembleEnergy(hour,) = weightEnergy.*predData.Energy(i, :);
            predData.SOC(hour,) = weightSOC.*predData.SOC(i, :);
        
            DetermPredSOC = weightSOC.*predSOC;
        end
    end
    %% Generate Result file
    % Headers for output file
    hedder = {'BuildingIndex', 'Year', 'Month', 'Day', 'Hour', 'Quarter', 'SOC_Mean', 'SOC_PImin', 'SOC_PIMax', ...
                      'EVDemandmean', 'EVDemandPImin', 'EVDemandPImax', 'Confidence Level'};
    fid = fopen(resultFilePath,'wt');
    fprintf(fid,'%s,',hedder{:});
    fprintf(fid,'\n');
    
    % Get Prediction Interval 
    % Input: 
    %   1. Deterministic forecasting result
    %   2. Predictors
    %   3. Err distribution (24*4 matrix)
    [EnergyTransPImean, EnergyTransPImin, EnergyTransPImax] = getPI(DetermPredEnergy, predictors, errDist.Energy);
    [SOCPImean, SOCPImin, SOCPImax] = getPI(DetermPredSOC, predictors, errDist.SOC);
    
    result = [predictors(:,1:6)  SOCPImean SOCPImin SOCPImax EnergyTransPImean EnergyTransPImin EnergyTransPImax... 
                   100*(1-ci_percentage)*ones(size(DetermPredEnergy,1),1)];
    fprintf(fid,['%d,', '%04d,', '%02d,', '%02d,', '%2d,','%1d,', '%f,', '%f,', '%f,', '%f,', '%f,', '%f,','%d', '\n'], result');
    fclose(fid);
    
    % for debugging --------------------------------------------------------
    EnergyTransPI =  [EnergyTransPImin, EnergyTransPImax];
    SOCPI =  [SOCPImin, SOCPImax];
    observed = csvread('TargetEVData.csv',1,0);
    display_result('EnergyTrans', EnergyTransPI, num_instances, DetermPredEnergy, observed(:,9), ci_percentage);
    display_result('SOC', SOCPI, num_instances, DetermPredSOC, observed(:,10), ci_percentage);
    % for debugging --------------------------------------------------------------------- 
    
    flag = 1;
    toc;
end
