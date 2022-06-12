warning off;
clear;
clc;
close all;

perc = 0.8;
bound_perc = 0.2;
it = 5;
Description = strings(it, 1);
Manual_u = zeros(it, 1);
KH_u = zeros(it, 1);
Manual_t = zeros(it, 1);
KH_t = zeros(it, 1);


% Iris initialize


[dataset, value] = iris_dataset;
dataset = dataset.';
value = vec2ind(value)';
dataset = [dataset, value];
n = size(dataset, 1);

% seeds initialize
%dataset = readmatrix('seeds.csv');
%n = size(dataset, 1);

%wine initialize

% [dataset, value] = wine_dataset;
% dataset = dataset.';
% value = vec2ind(value)';
% dataset = [dataset([1:50 52:100 102:150 152:end], 1:8), value([1:50 52:100 102:150 152:end])];
% n = size(dataset, 1);


dataset = dataset(randperm(size(dataset, 1)), :);

% main loop
for loop = 1:it

    x_train = dataset([1:round(n*((loop-1)/it)) round(n*((loop)/it)+1):end], 1:size(dataset, 2)-1);
    y_train = dataset([1:round(n*((loop-1)/it)) round(n*((loop)/it)+1):end], size(dataset, 2));

    x_testing = dataset([n*((loop-1)/it)+1:n*((loop)/it)], 1:size(dataset, 2)-1);
    y_testing = dataset([n*((loop-1)/it)+1:n*((loop)/it)], size(dataset, 2));

    fprintf('Iteracja: %d\n', loop);
    Description(loop) = convertCharsToStrings(sprintf('Iteracja: %d (%%)', loop));

    %%--%%--%% Inicjalizacja FIS
    fis = readfis('sug41.fis');

    y_out = evalfis(fis, x_train);
    y_test = evalfis(fis, x_testing);

    %testing fis before Herd alghoritm
    y_temp = y_out;
    for i = 1:size(y_temp, 1)
        y_temp(i) = round(y_temp(i));
    end
    temp = y_temp - y_train;
    q = sum(temp == 0);
    fprintf('Percentage of corectly qualified cases (manual FIS) - teaching set: %.0f%%\n', round(q / size(y_out, 1), size(dataset, 2)) * 100);
    Manual_u(loop) = round(q / size(y_out, 1), size(dataset, 2)) * 100;
    y_temp = y_test;
    for i = 1:size(y_temp, 1)
        y_temp(i) = round(y_temp(i));
    end
    temp = y_temp - y_testing;
    q = sum(temp == 0);
    fprintf('Percentage of corectly qualified cases (manual FIS) - testing set: %.0f%%\n', round(q / size(y_test, 1), size(dataset, 2)) * 100);
    Manual_t(loop) = round(q / size(y_test, 1), size(dataset, 2)) * 100;

    %%--%%--%% Wykresy wyników (manual FIS)
    figure;
    subplot(2, 1, 1)
    scatter(1:n*perc, y_out, 55, 'r', 'd')
    hold on;
    scatter(1:n*perc, y_train, 'b', 'filled')
    legend('ymodel', 'yreal')
    title('Zbior uczacy');
    subplot(2, 1, 2)
    scatter(1:(n - n * perc), y_test, 55, 'r', 'd')
    hold on;
    scatter(1:(n - n * perc), y_testing, 'b', 'filled')
    legend('ymodel', 'yreal')
    title('Zbior testujacy');

    %getting parameters from fis
    [in, out] = getTunableSettings(fis);
    paramVals = getTunableValues(fis, [in; out]);

    % calculating boundary
    LB = [];
    UB = [];
    bound_in = [];

    for i = 1:size(dataset, 2) - 1
        temp = fis.Inputs(i).MembershipFunctions.Parameters;
        bound_in = [bound_in, size(fis.Inputs(i).MembershipFunctions, 2) * size(temp, 2)];
    end

    for r = 1:size(dataset, 2) - 1
        for i = 1:min(bound_in)
            LB(end+1) = fis.Inputs(r).Range(1) - fis.Inputs(r).Range(1) * bound_perc;
            UB(end+1) = fis.Inputs(r).Range(2) + fis.Inputs(r).Range(2) * bound_perc;
        end
    end
   
    x = KH(fis, LB, UB, @cost, x_train, y_train);
    fis = setTunableValues(fis, in, x.');
    y_out = evalfis(fis, x_train);
    y_test = evalfis(fis, x_testing);

    %testing fis after Kril Herd alghoritm
    y_temp = y_out;
    for i = 1:size(y_temp, 1)
        y_temp(i) = round(y_temp(i));
    end
    temp = y_temp - y_train;
    q = sum(temp == 0);
    fprintf('Percentage of corectly qualified cases (KH) - teaching set:  %.0f%%\n', round(q / size(y_out, 1), size(dataset, 2)) * 100);
    KH_u(loop) = round(q / size(y_out, 1), 5) * 100;

    y_temp = y_test;
    for i = 1:size(y_temp, 1)
        y_temp(i) = round(y_temp(i));
    end
    temp = y_temp - y_testing;
    q = sum(temp == 0);
    fprintf('Percentage of corectly qualified cases (KH) - testing set:  %.0f%%\n', round(q / size(y_test, 1), size(dataset, 2)) * 100);
    KH_t(loop) = round(q / size(y_test, 1), size(dataset, 2)) * 100;
end

Glowna_srednia_Manual = mean(Manual_t)
wariancja_Manual=0;
for i = 1:length(Manual_t)
    wariancja_Manual = wariancja_Manual + (Manual_t(i)-Glowna_srednia_Manual)^2;
end
wariancja_Manual = wariancja_Manual/length(Manual_t);
odchylenie_standardowe_Manual=sqrt(wariancja_Manual)   

Glowna_srednia_KH = mean(KH_t)
wariancja=0;
for i = 1:length(KH_t)
    wariancja = wariancja + (KH_t(i)-Glowna_srednia_KH)^2;
end
wariancja = wariancja/length(KH_t);
odchylenie_standardowe_KH=sqrt(wariancja)   


%%%%%%%%%%%%%%%%%%%%%Porównanie z SubtractiveClustering
SC_t = zeros(it, 1);
SC_u = zeros(it, 1);
for loop = 1:it
    x_u = dataset(1:n*perc, 1:end-1);
    y_u = dataset(1:n*perc, end);
    x_t = dataset(n*perc+1:end, 1:end-1);
    y_t = dataset(n*perc+1:end, end);
    
    fprintf('Iteracja: %d\n', loop);
    Description(loop) = convertCharsToStrings(sprintf('Iteracja: %d (%%)', loop));

    %%--%%--%% Inicjalizacja FIS
    optionsSC = genfisOptions('SubtractiveClustering');
    fis_SC = genfis(x_u, y_u, optionsSC);
    
    y_out = evalfis(fis_SC, x_u);
    y_test = evalfis(fis_SC, x_t);

    y_temp = y_out;
    for i = 1:size(y_temp, 1)
        y_temp(i) = round(y_temp(i));
    end
    temp = y_temp - y_u;
    q = find(temp == 0);
    fprintf('Percentage of corectly qualified cases (SubtractiveClustering FIS) -teaching set: %.3f%%\n', round(size(q, 1) / size(y_out, 1), size(dataset, 2)) * 100);
    SC_u(loop) = round(size(q, 1) / size(y_out, 1), size(dataset, 2)) * 100;

    y_temp = y_test;
    for i = 1:size(y_temp, 1)
        y_temp(i) = round(y_temp(i));
    end
    temp = y_temp - y_t;
    q = find(temp == 0);
    fprintf('Percentage of corectly qualified cases (SubtractiveClustering FIS) -test set: %.3f%%\n', round(size(q, 1) / size(y_test, 1), size(dataset, 2)) * 100);
    SC_t(loop) = round(size(q, 1) / size(y_test, 1), size(dataset, 2)) * 100;
end

Glowna_srednia_SC = mean(SC_t)
wariancja_SC=0;
for i = 1:length(SC_t)
    wariancja_SC = wariancja_SC + (SC_t(i)-Glowna_srednia_SC)^2;
end
wariancja_SC = wariancja_SC/length(SC_t);
odchylenie_standardowe_SC=sqrt(wariancja_SC) 


function fitness = cost(x, fis, x_u, y_u)
for i = 1:size(x, 2)
    if x(i) == 0
        x(i) = 0.001 + rand * (0.05 - 0.001);
    end
end

fis_test = fis;
in = getTunableSettings(fis_test);

paramVals = x;
fis_test = setTunableValues(fis_test, in, paramVals.');

y_kh = evalfis(fis_test, x_u);

for i = 1:size(y_kh, 1)
    y_kh(i) = round(y_kh(i));
end

temp = y_kh - y_u;
q = sum(temp == 0);

fitness = (size(y_kh, 1) - q) / size(y_kh, 1);

end