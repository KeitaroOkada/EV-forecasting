clear all;
clc;
close all;



y_pred = getEVModel([pwd,'\','shortTermEVData.csv'],...
                        [pwd,'\','forecastEVData.csv'],...
                        [pwd,'\','resultEVData.csv'])