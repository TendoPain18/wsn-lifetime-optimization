function [cycles, active_nodes, T1, energy_at_T1] = ...
    simulate_wsn_rotation(nodes_x, nodes_y, sink_x, sink_y, N, E_init, C, ...
    E_elec, eps_amp_short, eps_amp_long, E_agg, data_packet_size, ...
    overhead_packet_size, d0)
% SIMULATE_WSN_ROTATION Simulates WSN with rotating cluster heads
%
% Inputs:
%   nodes_x, nodes_y: Node positions
%   sink_x, sink_y: Sink position
%   N: Number of nodes
%   E_init: Initial energy per node (J)
%   C: Cycles between CH rotation
%   E_elec, eps_amp_short, eps_amp_long: Energy parameters
%   E_agg: Aggregation energy
%   data_packet_size, overhead_packet_size: Packet sizes (bits)
%   d0: Distance threshold
%
% Outputs:
%   cycles: Array of cycle numbers
%   active_nodes: Number of active nodes at each cycle
%   T1: Lifetime to first node death
%   energy_at_T1: Energy vector at T1

% Initialize energy
energy = E_init * ones(N, 1);
is_alive = true(N, 1);

% Storage for results
cycles = [];
active_nodes = [];
cycle = 0;
T1 = -1;
energy_at_T1 = [];
first_death_recorded = false;

% Main simulation loop
max_cycles = 5000;  % Safety limit
while sum(is_alive) > 0 && cycle < max_cycles
    cycle = cycle + 1;
    
    % Progress indicator (every 100 cycles)
    if mod(cycle, 100) == 0
        fprintf('    Cycle %d: %d nodes alive\n', cycle, sum(is_alive));
    end
    
    % Check if we need to elect new CHs
    if mod(cycle - 1, C) == 0
        % Elect new cluster heads (5% of nodes)
        num_ch = max(1, round(0.05 * N));
        ch_indices = elect_cluster_heads(nodes_x, nodes_y, sink_x, sink_y, ...
            energy, is_alive, num_ch, C, E_elec, eps_amp_short, ...
            eps_amp_long, E_agg, data_packet_size, overhead_packet_size, d0);
        
        if isempty(ch_indices)
            % No valid CHs can be found, network is dying
            break;
        end
        
        % Form clusters: assign each node to nearest CH
        clusters = assign_to_clusters(nodes_x, nodes_y, ch_indices, is_alive);
    end
    
    % Energy consumption for this cycle
    is_ch = false(N, 1);
    is_ch(ch_indices) = true;
    
    % Process each node
    for i = 1:N
        if ~is_alive(i)
            continue;
        end
        
        if is_ch(i)
            % This node is a CH
            % 1. Receive data from cluster members
            members = find(clusters == i);
            members = members(members ~= i);  % Exclude self
            
            for m = members'
                if is_alive(m)
                    % Receive overhead packet from member
                    E_rx = overhead_packet_size * E_elec;
                    energy(i) = energy(i) - E_rx;
                end
            end
            
            % 2. Aggregate data
            num_signals = sum(is_alive(members)) + 1;  % Members + self
            E_aggregation = data_packet_size * E_agg * num_signals;
            energy(i) = energy(i) - E_aggregation;
            
            % 3. Transmit aggregated data to sink
            dist_to_sink = sqrt((nodes_x(i) - sink_x)^2 + (nodes_y(i) - sink_y)^2);
            E_tx = transmit_energy(data_packet_size, dist_to_sink, ...
                E_elec, eps_amp_short, eps_amp_long, d0);
            energy(i) = energy(i) - E_tx;
            
        else
            % Regular node: send data to nearest CH
            ch_idx = clusters(i);
            if is_alive(ch_idx)
                dist_to_ch = sqrt((nodes_x(i) - nodes_x(ch_idx))^2 + ...
                                  (nodes_y(i) - nodes_y(ch_idx))^2);
                E_tx = transmit_energy(overhead_packet_size, dist_to_ch, ...
                    E_elec, eps_amp_short, eps_amp_long, d0);
                energy(i) = energy(i) - E_tx;
            end
        end
        
        % Check if node died
        if energy(i) <= 0
            is_alive(i) = false;
            energy(i) = 0;
        end
    end
    
    % Record statistics
    cycles(end+1) = cycle;
    active_nodes(end+1) = sum(is_alive);
    
    % Record first node death
    if ~first_death_recorded && sum(is_alive) < N
        T1 = cycle;
        energy_at_T1 = energy;
        first_death_recorded = true;
    end
    
    % Safety check: prevent infinite loops
    if cycle > max_cycles
        fprintf('    WARNING: Reached maximum cycles (%d)\n', max_cycles);
        break;
    end
end

% If no node died (shouldn't happen but just in case)
if T1 == -1
    T1 = cycle;
    energy_at_T1 = energy;
end

end


function ch_indices = elect_cluster_heads(nodes_x, nodes_y, sink_x, sink_y, ...
    energy, is_alive, num_ch, C, E_elec, eps_amp_short, eps_amp_long, ...
    E_agg, data_packet_size, overhead_packet_size, d0)
% ELECT_CLUSTER_HEADS Selects nodes as CHs based on energy
%
% CHs must have enough energy to:
% 1. Receive from potential cluster members
% 2. Aggregate data
% 3. Transmit to sink
% ... for at least C cycles

% Find alive nodes
alive_indices = find(is_alive);

if length(alive_indices) < num_ch
    num_ch = length(alive_indices);
end

if num_ch == 0
    ch_indices = [];
    return;
end

% Calculate minimum energy required for a CH
% Assume worst case: CH receives from all other nodes
dist_to_sink_max = sqrt((nodes_x - sink_x).^2 + (nodes_y - sink_y).^2);
E_tx_to_sink = transmit_energy(data_packet_size, dist_to_sink_max, ...
    E_elec, eps_amp_short, eps_amp_long, d0);

% Estimate energy per cycle for CH (conservative estimate)
E_per_cycle = E_tx_to_sink + ...  % Transmit to sink
              overhead_packet_size * E_elec * 20 + ...  % Receive from ~20 members (avg)
              data_packet_size * E_agg * 20;  % Aggregate ~20 signals

% Required energy for C cycles
E_required = C * E_per_cycle;

% Select nodes with highest energy that meet the requirement
[sorted_energy, sort_idx] = sort(energy(alive_indices), 'descend');
valid_candidates = alive_indices(sort_idx(sorted_energy > E_required(alive_indices(sort_idx))));

if length(valid_candidates) >= num_ch
    ch_indices = valid_candidates(1:num_ch);
else
    % Not enough valid candidates, select best available
    ch_indices = alive_indices(sort_idx(1:min(num_ch, length(alive_indices))));
end

end


function clusters = assign_to_clusters(nodes_x, nodes_y, ch_indices, is_alive)
% ASSIGN_TO_CLUSTERS Assigns each node to nearest cluster head
%
% Outputs:
%   clusters: Vector where clusters(i) is the CH index for node i

N = length(nodes_x);
clusters = zeros(N, 1);

for i = 1:N
    if ~is_alive(i)
        continue;
    end
    
    % Calculate distance to each CH
    min_dist = inf;
    nearest_ch = ch_indices(1);
    
    for ch = ch_indices'
        dist = sqrt((nodes_x(i) - nodes_x(ch))^2 + (nodes_y(i) - nodes_y(ch))^2);
        if dist < min_dist
            min_dist = dist;
            nearest_ch = ch;
        end
    end
    
    clusters(i) = nearest_ch;
end

end


function E_tx = transmit_energy(packet_size, distance, E_elec, ...
    eps_amp_short, eps_amp_long, d0)
% TRANSMIT_ENERGY Calculates transmission energy
%
% Uses free space model for d <= d0, multipath model for d > d0
% Handles both scalar and vector distances

% Element-wise operations for vector compatibility
if isscalar(distance)
    % Single distance value
    if distance <= d0
        % Free space model
        E_tx = packet_size * E_elec + packet_size * eps_amp_short * distance^2;
    else
        % Multipath fading model
        E_tx = packet_size * E_elec + packet_size * eps_amp_long * distance^4;
    end
else
    % Vector of distances - use element-wise operations
    E_tx = packet_size * E_elec * ones(size(distance));
    
    % Free space model for short distances
    short_idx = distance <= d0;
    E_tx(short_idx) = E_tx(short_idx) + packet_size * eps_amp_short * distance(short_idx).^2;
    
    % Multipath model for long distances
    long_idx = distance > d0;
    E_tx(long_idx) = E_tx(long_idx) + packet_size * eps_amp_long * distance(long_idx).^4;
end

end