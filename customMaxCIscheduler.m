classdef customMaxCIscheduler < nrScheduler
    % Max Carrier-to-Interference (C/I) scheduler for 5G NR using CQI

    methods (Access = protected)
        function dlAssignments = scheduleNewTransmissionsDL(obj, timeResource, frequencyResource, schedulingInfo)
            % Schedule new DL transmissions using Max C/I scheduling
            
            % Get eligible UEs and available RBGs
            eligibleUEs = schedulingInfo.EligibleUEs;
            numEligibleUEs = numel(eligibleUEs);
            if numEligibleUEs == 0
                dlAssignments = []; % No UEs to schedule
                return;
            end

            % Find available RBGs
            availableRBGs = find(frequencyResource == 0);
            numAvailableRBGs = numel(availableRBGs);
            if numAvailableRBGs == 0
                dlAssignments = []; % No resources to allocate
                return;
            end

            % Initialize arrays for metrics and MCS indices
            CIratio = zeros(1, numEligibleUEs);
            estimatedDataRate = zeros(1, numEligibleUEs);
            mcsIndices = zeros(1, numEligibleUEs);

            % Compute C/I ratio for each eligible UE using CQI
            for i = 1:numEligibleUEs
                ueRNTI = eligibleUEs(i);
                ueContext = obj.UEContext(ueRNTI);

                % Use reported CQI for channel quality
                cqi = ueContext.CSIMeasurementDL.CSIRS.CQI; % Assume CQI is directly accessible
                channelQuality = obj.getSpectralEfficiencyFromCQI(cqi);

                % Estimate interference (in bps/Hz)
                interference = obj.estimateInterference();

                % Compute C/I ratio
                CIratio(i) = channelQuality / max(interference, 1e-6); % Avoid division by zero

                % Estimate MCS index and data rate
                mcsIndex = obj.estimateMCSIndexFromCQI(cqi);
                mcsIndices(i) = mcsIndex;
                estimatedDataRate(i) = CIratio(i) * 1; % Assuming one RBG
            end

            disp("CI Metrics:");
            for i = 1:numEligibleUEs
                disp(['UE RNTI: ', num2str(eligibleUEs(i)), ...
                      ', CI Metric: ', num2str(CIratio(i))]);
            end

            % Sort UEs based on C/I ratio in descending order
            [~, sortedIndices] = sort(CIratio, 'descend');
            sortedUEs = eligibleUEs(sortedIndices);
            sortedMCSIndices = mcsIndices(sortedIndices);

            % Allocate resources to UEs based on sorted C/I
            dlAssignments = [];
            currentRBGIndex = 1;

            for idx = 1:numEligibleUEs
                ueRNTI = sortedUEs(idx);
                mcsIndex = sortedMCSIndices(idx);

                % Check if any RBGs are left
                if currentRBGIndex > numAvailableRBGs
                    break;
                end

                % Assign one RBG to this UE
                assignedRBG = availableRBGs(currentRBGIndex);
                currentRBGIndex = currentRBGIndex + 1;

                % Update frequency allocation
                FrequencyAllocation = zeros(1, length(frequencyResource), 'double');
                FrequencyAllocation(assignedRBG) = 1;

                % Get precoder from UE context
                ueContext = obj.UEContext(ueRNTI);
                if isempty(ueContext.CSIMeasurementDL.CSIRS.W)
                    precoder = eye(1, 'double');
                else
                    precoder = ueContext.CSIMeasurementDL.CSIRS.W;
                end

                % Create assignment structure
                assignment.RNTI = double(ueRNTI);
                assignment.FrequencyAllocation = double(FrequencyAllocation);
                assignment.W = double(precoder);
                assignment.MCSIndex = double(mcsIndex);

                % Add this assignment to the list
                dlAssignments = [dlAssignments; assignment];
            end
        end

        function interference = estimateInterference(obj)
            % Generate random interference between -90 and -70 dBm
            interference_dBm = -90 + (rand() * (-70 - (-90))); % Random value in dBm
            interference_W = 10^((interference_dBm - 30) / 10); % Convert dBm to W

            % Convert interference to bps/Hz using Shannon Capacity formula
            bandwidth_Hz = 20e6; % Assume 1 MHz bandwidth for simplicity
            interference = log2(1 + interference_W / bandwidth_Hz); % Spectral efficiency (bps/Hz)
        end

        function spectralEfficiency = getSpectralEfficiencyFromCQI(obj, cqi)
            % Map CQI to spectral efficiency
            % CQI values range from 0 to 15, corresponding to different MCS levels
            cqiToSpectralEfficiency = [
                0.1523, 0.2344, 0.3770, 0.6016, 0.8770, 1.1758, 1.4766, ...
                1.9141, 2.4063, 2.7305, 3.3223, 3.9023, 4.5234, 5.1152, ...
                5.5547, 6.2266
            ];
            spectralEfficiency = cqiToSpectralEfficiency(max(1, min(cqi + 1, 16))); % Map CQI to efficiency
        end

        function mcsIndex = estimateMCSIndexFromCQI(obj, cqi)
            % Estimate MCS index from CQI
            % Assume a direct mapping between CQI and MCS index
            mcsIndex = min(cqi, 27); % Cap MCS index at 27
        end
    end
end
