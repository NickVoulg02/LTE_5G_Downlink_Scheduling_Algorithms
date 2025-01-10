classdef customEPFscheduler < nrScheduler
    % Custom Exponential Proportional Fair scheduler for 5G NR

    properties (Access = private)
        AverageThroughput % Map from RNTI to average throughput
    end

    methods
        function obj = customEPFscheduler()
            % Constructor to initialize the AverageThroughput map
            obj.AverageThroughput = containers.Map('KeyType', 'double', 'ValueType', 'double');
        end
    end

    methods (Access = protected)
        function dlAssignments = scheduleNewTransmissionsDL(obj, timeResource, frequencyResource, schedulingInfo)
            % Schedule new DL transmissions using Proportional Fair scheduling
            
            % Get eligible UEs and available RBGs
            eligibleUEs = schedulingInfo.EligibleUEs;
            numEligibleUEs = numel(eligibleUEs); % Store number of elements
            if numEligibleUEs == 0
                dlAssignments = []; % No UEs to schedule
                return;
            end
            disp("Eligible UEs:");
            disp(eligibleUEs);

            
            % Find available RBGs
            availableRBGs = find(frequencyResource == 0); % Return array
            numAvailableRBGs = numel(availableRBGs);
            disp(['Total RBGs: ', num2str(length(frequencyResource))]);
            disp(['Number of Available RBGs: ', num2str(numAvailableRBGs)]);
            disp(frequencyResource);
           
            if numAvailableRBGs == 0
                dlAssignments = []; % No resources to allocate
                return;
            end

            % Initialize arrays to store PF metrics
            EPFmetric = zeros(1, numEligibleUEs);
            estimatedDataRate = zeros(1, numEligibleUEs);
            mcsIndices = zeros(1, numEligibleUEs);
            spectralEfficiencies = zeros(1, numEligibleUEs);

            % For each eligible UE, compute PF metric
            for i = 1:numEligibleUEs
                ueRNTI = eligibleUEs(i);

                % Existing UEs retrieve historic average throughput
                if isKey(obj.AverageThroughput, ueRNTI)
                    avgThroughput = obj.AverageThroughput(ueRNTI);
                else
                    avgThroughput = 1; % You can adjust this initial value
                end

                % Estimate instantaneous data rate based on channel conditions
                % For simplicity, we'll assign random MCS indices
                ueContext = obj.UEContext(ueRNTI);
                mcsIndex = obj.estimateMCSIndex(ueContext);
                mcsIndices(i) = mcsIndex;

                % Get the spectral efficiency from MCS index
                spectralEfficiency = obj.getSpectralEfficiency(mcsIndex);
                spectralEfficiencies(i) = spectralEfficiency;

                % Estimate instantaneous data rate (assuming one RBG)
                estimatedDataRate(i) = spectralEfficiency * 1; % Multiply by number of RBGs (1)

                % Compute Exponential PF metric
                % Higher metrics prioritize UEs with high data rates relative to their average throughput.
                beta = 2; % Weighting factor for fairness  0.1 0.5 2 δοκιμασε
                epsilon = 1e-3; % Minimum value for the exponential term
                expTerm = exp(-beta * avgThroughput);
                expTerm = max(expTerm, epsilon); % Ensure the term is not too small
                EPFmetric(i) = estimatedDataRate(i) * expTerm;
            end

            % Normalize metrics to a [0, 1] range
            %if max(EPFmetric) > 0 % Avoid division by zero
            %    EPFmetric = EPFmetric / max(EPFmetric);
            %end

            disp("EPF Metrics:");
            for i = 1:numEligibleUEs
                disp(['UE RNTI: ', num2str(eligibleUEs(i)), ...
                      ', PF Metric: ', num2str(EPFmetric(i)), ...
                      ', Estimated Data Rate: ', num2str(estimatedDataRate(i))]);
            end


            % Sort UEs based on PF metric descending order
            [~, sortedIndices] = sort(EPFmetric, 'descend');
            sortedUEs = eligibleUEs(sortedIndices);
            sortedSpectralEfficiencies = spectralEfficiencies(sortedIndices);
            sortedMCSIndices = mcsIndices(sortedIndices);

            % Allocate resources to UEs in order of PF metric
            dlAssignments = [];
            currentRBGIndex = 1;
            totalRemainingRBGs = numAvailableRBGs;
            disp(["numEligibleUEs: ", num2str(numEligibleUEs)]);

            % Loop through sorted UEs and assign resources
            for idx = 1:numEligibleUEs
               % disp(["Position in sorted array: ", num2str(idx)]);
               
                ueRNTI = sortedUEs(idx);
                %disp(["RNTI :", num2str(ueRNTI)]);

                spectralEfficiency = sortedSpectralEfficiencies(idx);
                mcsIndex = sortedMCSIndices(idx);

                % Determine number of RBGs to assign proportionally
                % UEs with higher PF metrics get a proportionally larger share of RBGs
                proportion = EPFmetric(sortedIndices(idx)) / sum(EPFmetric(sortedIndices(idx:end)));
                numRBGsToAssign = max(floor(proportion * totalRemainingRBGs), 1); % At least 1 RBG

                % Check if enough RBGs are left
                if currentRBGIndex + numRBGsToAssign - 1 > numAvailableRBGs
                    numRBGsToAssign = numAvailableRBGs - currentRBGIndex + 1;
                end

                % Assign RBGs to this UE respecting resource constraints
                assignedRBGs = availableRBGs(currentRBGIndex : currentRBGIndex + numRBGsToAssign - 1);
                disp(["Assigned :", num2str(assignedRBGs)]);
                currentRBGIndex = currentRBGIndex + numRBGsToAssign;
                totalRemainingRBGs = totalRemainingRBGs - numRBGsToAssign;

                % Update frequency allocation for this UE
                FrequencyAllocation = zeros(1, length(frequencyResource), 'double');
                FrequencyAllocation(assignedRBGs) = 1;
                % Get UE context for precoder
                ueContext = obj.UEContext(ueRNTI);

                % Handle precoder
                if isempty(ueContext.CSIMeasurementDL.CSIRS.W)
                    precoder = eye(1, 'double'); % Default precoder as [1 x 1]
                else
                    precoder = ueContext.CSIMeasurementDL.CSIRS.W;
                end

                % Enforce precoder dimensions
                [numLayers, ngnbTx] = size(precoder);
                if numLayers == 0 || ngnbTx == 0
                    precoder = eye(1, 'double'); % Default [1 x 1] matrix
                end

                % Create the assignment structure
                % Encapsulate all scheduling decisions into an assignment structure
                assignment.RNTI = double(ueRNTI);
                assignment.FrequencyAllocation = double(FrequencyAllocation);
                assignment.W = double(precoder);
                assignment.MCSIndex = double(mcsIndex);

                % Add this assignment to the list
                dlAssignments = [dlAssignments; assignment];

                % Update average throughput using exponential moving average
                % Smooths throughput updates to ensure a balance between fairness and responsiveness
                assignedDataRate = spectralEfficiency * numRBGsToAssign;
                alpha = 0.5; % Smoothing factor for responsiveness
                if isKey(obj.AverageThroughput, ueRNTI)
                    obj.AverageThroughput(ueRNTI) = (1 - alpha) * assignedDataRate + alpha * obj.AverageThroughput(ueRNTI);

                else
                    obj.AverageThroughput(ueRNTI) = assignedDataRate;
                end
                
                % Break if no RBGs left
                if currentRBGIndex > numAvailableRBGs
                    break;
                end
            end
        end

          function mcsIndex = estimateMCSIndex(obj, ueContext)
            % Assign random MCS indices for demonstration
            mcsIndex = randi([0, 27]); % MCS index between 0 and 27
        end


        function spectralEfficiency = getSpectralEfficiency(obj, mcsIndex)
            % Return spectral efficiency based on MCS index
            mcsTable = [
                0.2344, 0.3770, 0.6016, 0.8770, 1.1758, 1.4766, 1.6953, 1.9141, ...
                2.1602, 2.4063, 2.5703, 2.7305, 3.0293, 3.3223, 3.6094, 3.9023, ...
                4.2129, 4.5234, 4.8164, 5.1152, 5.3320, 5.5547, 5.8906, 6.2266, ...
                6.5703, 6.9141, 7.1602, 7.4063
            ];
            spectralEfficiency = mcsTable(mcsIndex + 1); % Map MCS index to spectral efficiency
        end
    end
end
