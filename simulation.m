function [averageThroughput, jainsFairnessIndex] = simulationRun(UEnum, schedulerType)
	% Initialize wireless network simulator.
	networkSimulator = wirelessNetworkSimulator.init;
	numFrameSimulation = 10; % Simulation time in terms of number of 10 ms frames
	rng("default")          % Reset the random number generator


	% Create a gNB node
	%  Duplex mode — Frequency division duplex
	%  Channel bandwidth — 30 MHz
	%  Subcarrier spacing — 15 KHz 
	gNB = nrGNB(Position=[0 0 0],DuplexMode="FDD",CarrierFrequency=2.6e9, ...
        ChannelBandwidth= 20e6, SubcarrierSpacing= 30e3, ...
        NumResourceBlocks=20);

	% Define the random range for UE positions around gNB
	positionRange = 1000; % Set the range for x and y positions around the gNB

	% Generate random positions around gNB with a fixed z-coordinate
	uePositions = [positionRange * (rand(UEnum, 1) - 0.5), ...  % Random x positions around gNB within +/- 500 meters
	               positionRange * (rand(UEnum, 1) - 0.5), ...  % Random y positions around gNB within +/- 500 meters
	               zeros(UEnum, 1)];                        % Fixed z-coordinate for all UEs

	% Generate unique names for each UE
	ueNames = "UE-" + (1:UEnum);

	% Create UE nodes with specified properties
	UEs = nrUE(Name=ueNames, Position=uePositions);


	% Configure a scheduler at the gNB
    if ischar(schedulerType) || isstring(schedulerType)
        % Use the built-in scheduler specified by name
        configureScheduler(gNB, Scheduler=schedulerType, ResourceAllocationType=0);
    else
        % Instantiate the custom scheduler
        customScheduler = schedulerType();
        configureScheduler(gNB, Scheduler=customScheduler, ResourceAllocationType=0);
    end

	% Connect the UE nodes to the gNB node.
	connectUE(gNB,UEs,FullBufferTraffic="DL")
    
    %{
    connectUE(gNB, UEs);
    traffic = cell(1, UEnum);
    
    % Define traffic parameters for each group
    numPacketsPerGroup = [8, 16, 32, 64]; % Number of packets for each group
    groupSize = floor(UEnum / 4); % Number of UEs per group (approximately equal division)
    
    % Adjust traffic generation logic for each group
    for i = 1:UEnum
        % Determine which group the UE belongs to
        groupIndex = min(ceil(i / groupSize), 4); % Ensure group index is within bounds
        numPackets = numPacketsPerGroup(groupIndex); % Get numPackets for this group
    
        % Create FTP traffic generator for this UE
        traffic{i} = networkTrafficFTP(GeneratePacket=true);
        
        dt = zeros(1, numPackets);           % Inter-arrival times (milliseconds)
        packetSize = zeros(1, numPackets);  % Packet sizes (bytes)
        packets = cell(1, numPackets);      % Packet data
    
        for idx = 1:numPackets
            % Generate traffic packets
            [dt(idx), packetSize(idx), packets{idx}] = generate(traffic{i});
        end
    
        % Add traffic source to gNB with the specific UE as the destination
        addTrafficSource(gNB, traffic{i}, DestinationNode=UEs(i));
    end
    
    
    
    % Define traffic parameters
    numPackets = 16; % Number of packets to generate per UE
    
    % Adjust traffic generation logic
    for i = 1:UEnum
        % Create VoIP traffic generator
        %traffic{i} = networkTrafficVoIP(GeneratePacket=true);
        traffic{i} = networkTrafficVoIP(GeneratePacket=true)
        
        dt = zeros(1, numPackets);           % Inter-arrival times (milliseconds)
        packetSize = zeros(1, numPackets);  % Packet sizes (bytes)
        packets = cell(1, numPackets);      % Packet data
    
        for idx = 1:numPackets
            % Generate traffic packets
            [dt(idx), packetSize(idx), packets{idx}] = generate(traffic{i});
        end

        % Add traffic source to gNB with the specific UE as the destination
        addTrafficSource(gNB, traffic{i}, DestinationNode=UEs(i));
    end
    %}

	% Add the nodes to the network simulator.
	addNodes(networkSimulator,gNB)
	addNodes(networkSimulator,UEs)

	% Use 3GPP TR 38.901 channel model for all links. You can also run the example with a free space path loss model.
	%  Sets the propagation environment to "UMa" (Urban Macro), which is one of several deployment scenarios supported by 3GPP TR 38.901 
	%  ScenarioExtents: Specifies the simulation area boundaries in the x and y directions. 
	%  This ensures that the channel model accounts for distances and interactions between nodes within this area.
	channelModel = "3GPP TR 38.901";

    if strcmp(channelModel,"3GPP TR 38.901")
	    % Define scenario boundaries
	    pos = reshape([gNB.Position UEs.Position],3,[]);
	    minX = min(pos(1,:));          % x-coordinate of the left edge of the scenario in meters
	    minY = min(pos(2,:));          % y-coordinate of the bottom edge of the scenario in meters
	    width = max(pos(1,:)) - minX;  % Width (right edge of the 2D scenario) in meters, given as maxX - minX
	    height = max(pos(2,:)) - minY; % Height (top edge of the 2D scenario) in meters, given as maxY - minY

	    % Create the channel model
	    channel = h38901Channel(Scenario="UMa",ScenarioExtents=[minX minY width height]);
	    % Add the channel model to the simulator
	    addChannelModel(networkSimulator,@channel.channelFunction);
	    connectNodes(channel,networkSimulator);
    end
    
	% Run the simulation for the specified number of frames numFrameSimulation.
	% Calculate the simulation duration (in seconds)
	simulationTime = numFrameSimulation*1e-2;

    % Run the simulation
	run(networkSimulator,simulationTime);

	% Initialize an array to hold throughput values for each UE
	throughputUEs = zeros(UEnum,1);


	% Loop through each UE and calculate throughput
	for i = 1:UEnum
	    % Get statistics for each UE
	    ueStats = statistics(UEs(i));
	    macStats = ueStats.MAC;

	    % Display the MAC statistics for each UE
	    fprintf("MAC Statistics for %s:\n", ueNames(i));
	    disp(macStats);
	    
	    % Extract the total received bytes from the MAC statistics
	    if isfield(macStats, 'ReceivedBytes')
	        totalReceivedBits = macStats.ReceivedBytes * 8; % Convert bytes to bits
	    else
	        error('The field "ReceivedBytes" was not found in the MAC statistics.');
        end
        
        %global transmittedx;
        %global retransmittedx;
        %transmittedx(i) = macStats.DLTransmissionRB;
        %retransmittedx(i) = macStats.DLRetransmissionRB;

	    % Calculate throughput in bits per second
	    throughputUEs(i) = totalReceivedBits / simulationTime;
	    
	    % Display the throughput in Mbps
	    %fprintf('Throughput for %s: %.2f Mbps\n', ueNames(i), throughputUEs(i)/1e6);
	end


	% Calculate the average throughput across all UEs
	averageThroughput = mean(throughputUEs);

	% Display the average throughput in Mbps
	%fprintf('Average Throughput for all UEs: %.2f Mbps\n', averageThroughput / 1e6);

	% Calculate the Jains Fairness Index
	sumThroughput = sum(throughputUEs);
	sumThroughputSquared = sum(throughputUEs.^2);
	numUEs = length(throughputUEs);

	jainsFairnessIndex = (sumThroughput^2) / (numUEs * sumThroughputSquared);

	% Display the fairness index
	%fprintf("Jain's Fairness Index: %.4f\n", jainsFairnessIndex);
end


function channels = createMultiUserCDLChannels(channelConfig,gNB,UEs)
	    numUEs = length(UEs);
	    numNodes = length(gNB) + numUEs;
	    channels = cell(numNodes,numNodes);

	    waveformInfo = nrOFDMInfo(gNB.NumResourceBlocks,gNB.SubcarrierSpacing/1e3);
	    sampleRate = waveformInfo.SampleRate;

	    % Create a CDL channel model object configured with the desired delay
	    % profile, delay spread, and Doppler frequency
	    channel = nrCDLChannel;
	    channel.CarrierFrequency = gNB.CarrierFrequency;
	    % Delay profile. You can configure it as CDL- A,B,C,D,E
	    channel.DelayProfile = channelConfig.DelayProfile;
	    channel.DelaySpread = channelConfig.DelaySpread; % Delay Spread
	    % Configure antenna down-tilt as 12 (degrees)
	    channel.TransmitArrayOrientation = [0 12 0]';
	    channel.SampleRate = sampleRate;
	    channel.ChannelFiltering = false;

	    % For each UE set DL channel instance
	    for ueIdx = 1:numUEs

	        % Create a copy of the original channel
	        cdl = hMakeCustomCDL(channel);

	        % Configure the channel seed based on the UE number
	        % (results in independent fading for each UE)
	        cdl.Seed = 73 + (ueIdx - 1);

	        % Set antenna panel
	        cdl = hArrayGeometry(cdl,gNB.NumTransmitAntennas,UEs(ueIdx). ...
	            NumReceiveAntennas,"downlink");

	        % Compute the LOS angle from gNB to UE
	        [~,depAngle] = rangeangle(UEs(ueIdx).Position', ...
	            gNB.Position');

	        % Configure the azimuth and zenith angle offsets for this UE
	        cdl.AnglesAoD(:) = cdl.AnglesAoD(:) + depAngle(1);
	        % Convert elevation angle to zenith angle
	        cdl.AnglesZoD(:) = cdl.AnglesZoD(:) - cdl.AnglesZoD(1) + (90 - depAngle(2));

	        channels{gNB.ID,UEs(ueIdx).ID} = cdl;
	    end
end

% Number of Iterations
N = 25;

% Round Robin
averageThroughputsRR = zeros(1, N);
fairnessRR = zeros(1, N); 

%  Proportional Fair
averageThroughputsPF = zeros(1, N);
fairnessPF = zeros(1, N); 

% Packet Loss Ratio
%averageThroughputsPLS = zeros(1, N);
%fairnessPLS = zeros(1, N); 


% Packet Loss Ratio
%global transmittedx;
%global retransmittedx;
%global packetloss;

% Exponential Proportional Fair
averageThroughputsEPF = zeros(1, N);
fairnessEPF = zeros(1, N); % Exponential Proportional Fair

% Maximum C/I scheduler
averageThroughputsMaxCI = zeros(1, N);
fairnessMaxCI = zeros(1, N); % Max Carrier-to-Interface
iteration_num = 4 * (1:N);

for j = 1:N
    numUEs = iteration_num(j);
    
    % Proportional Fair Scheduler
    [averageThroughputsRR(j), fairnessRR(j)] = simulationRun(numUEs, "RoundRobin");

    
    %  Proportional Fair Scheduler
    [averageThroughputsPF(j), fairnessPF(j)] = simulationRun(numUEs, @customPFscheduler);

    % Packet Loss Ratio
    %packetloss = zeros(1, numUEs);
    %for k = 1 : numUEs
    %    packetloss(k) = retransmittedx(k)/transmittedx(k);
    %end

    %[averageThroughputsPLS(j),fairnessPLS(j)] = simulationRun(numUEs,@customPacketLossScheduler);

    % Exponential Proportional Fair Scheduler with beta=0.1
    [averageThroughputsEPF(j), fairnessEPF(j)] = simulationRun(numUEs, @customEPFscheduler);
    
    % Maximum C/I Scheduler
    [averageThroughputsMaxCI(j), fairnessMaxCI(j)] = simulationRun(numUEs, @customMaxCIscheduler);
end

% Combine and sort data for each scheduler
dataRR = [iteration_num', averageThroughputsRR', fairnessRR'];
sortedDataRR = sortrows(dataRR, 1);

dataPF = [iteration_num', averageThroughputsPF', fairnessPF'];
sortedDataPF = sortrows(dataPF, 1);

%dataPLS = [iteration_num', averageThroughputsPLS', fairnessPLS'];
%sortedDataPLS = sortrows(dataPLS, 1);

dataEPF = [iteration_num', averageThroughputsEPF', fairnessEPF'];
sortedDataEPF = sortrows(dataEPF, 1);

dataMaxCI = [iteration_num', averageThroughputsMaxCI', fairnessMaxCI'];
sortedDataMaxCI = sortrows(dataMaxCI, 1);


% Plot sorted data for Average Throughput
figure;
hold on;

% Round Robin
%plot(sortedDataRR(:,1), sortedDataRR(:,2), '-x', 'Color', [0 0.45 0.74], ...
%     'MarkerSize', 6, 'LineWidth', 1.5, 'MarkerFaceColor', [0 0.45 0.74]);

% Proportional Fair
plot(sortedDataPF(:,1), sortedDataPF(:,2), '-o', 'Color', [0.85 0.33 0.1], ...
    'MarkerSize', 6, 'LineWidth', 1.5, 'MarkerFaceColor', [0.85 0.33 0.1]);

% Packet Loss Ratio
%plot(sortedDataPLS(:,1), sortedDataPLS(:,2), '-d', 'Color', [0.6 0.22 0.2], ...
%    'MarkerSize', 6, 'LineWidth', 1.5, 'MarkerFaceColor', [0.6 0.22 0.2]);

% Exponential PF 
plot(sortedDataEPF(:,1), sortedDataEPF(:,2), '-s', 'Color', [0.2 0.6 0.5], ...
    'MarkerSize', 6, 'LineWidth', 1.5, 'MarkerFaceColor', [0.2 0.6 0.5]);

% Maximum C/I
%plot(sortedDataMaxCI(:,1), sortedDataMaxCI(:,2), '-p', 'Color', [0.5 0.1 0.1], ...
%    'MarkerSize', 6, 'LineWidth', 1.5, 'MarkerFaceColor', [0.5 0.1 0.1]);

hold off;
xlabel('Number of UEs', 'FontSize', 12, 'FontWeight', 'normal');
ylabel('Average Throughput (bps)', 'FontSize', 12, 'FontWeight', 'normal');
legend({'Proportional Fair', ...
       'Exponential PF \beta=2'}, 'Location', 'best');
%legend({'Round Robin', 'Proportional Fair', ...
%       'Exponential PF \beta=2', 'Max C/I'}, 'Location', 'best');
title('Average Throughput vs. Number of UEs', 'FontSize', 14, 'FontWeight', 'normal');
grid on;
set(gca, 'GridLineStyle', '--', 'GridColor', [0.5 0.5 0.5], 'GridAlpha', 0.5); % Dotted grid lines



% Plot sorted data for Jain's Fairness Index
figure;
hold on;

% Round Robin
%plot(sortedDataRR(:,1), sortedDataRR(:,3), '-x', 'Color', [0 0.45 0.74], ...
%    'MarkerSize', 6, 'LineWidth', 1.5, 'MarkerFaceColor', [0 0.45 0.74]);

% Proportional Fair
plot(sortedDataPF(:,1), sortedDataPF(:,3), '-o', 'Color', [0.85 0.33 0.1], ...
    'MarkerSize', 6, 'LineWidth', 1.5, 'MarkerFaceColor', [0.85 0.33 0.1]);

% Packet Loss Ratio
%plot(sortedDataPLS(:,1), sortedDataPLS(:,3), '-y', 'Color', [0.6 0.22 0.2], ...
%   'MarkerSize', 6, 'LineWidth', 1.5, 'MarkerFaceColor', [0.6 0.22 0.2]);

% Exponential PF
plot(sortedDataEPF(:,1), sortedDataEPF(:,3), '-s', 'Color', [0.2 0.6 0.5], ...
    'MarkerSize', 6, 'LineWidth', 1.5, 'MarkerFaceColor', [0.2 0.6 0.5]);

% Maximum C/I
%plot(sortedDataMaxCI(:,1), sortedDataMaxCI(:,3), '-p', 'Color', [0.5 0.1 0.1], ...
%    'MarkerSize', 6, 'LineWidth', 1.5, 'MarkerFaceColor', [0.5 0.1 0.1]);

hold off;
xlabel('Number of UEs', 'FontSize', 12, 'FontWeight', 'normal');
ylabel('Jain''s Fairness Index', 'FontSize', 12, 'FontWeight', 'normal');
legend({'Proportional Fair', ...
       'Exponential PF \beta=2'}, 'Location', 'best');
%legend({'Round Robin', 'Proportional Fair', ...
%       'Exponential PF \beta=2', 'Max C/I'}, 'Location', 'best');
title('Fairness Index vs. Number of UEs', 'FontSize', 14, 'FontWeight', 'normal');
grid on;
set(gca, 'GridLineStyle', '--', 'GridColor', [0.5 0.5 0.5], 'GridAlpha', 0.5); % Dotted grid lines







