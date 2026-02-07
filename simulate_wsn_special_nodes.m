function [cycles, active_nodes, T1, energy_at_T1, ch_x, ch_y] = ...
    simulate_wsn_special_nodes(nodes_x, nodes_y, sink_x, sink_y, N, E_init, R, ...
    E_elec, eps_amp_short, eps_amp_long, E_agg, data_packet_size, ...
    overhead_packet_size, d0)
% SIMULATE_WSN_SPECIAL_NODES Simulates WSN with dedicated special CH nodes
%
% Inputs:
%   nodes_x, nodes_y: Regular node positions
%   sink_x, sink_y: Sink position
%   N: Number of regular nodes
%   E_init: Initial energy per regular node (J)
%   R: Radius for CH placement around sink (m)
%   E_elec, eps_amp_short, eps_amp_long: Energy parameters
%   E_agg: Aggregation energy
%   data_packet_size, overhead_packet_size: Packet sizes (bits)
%   d0: Distance threshold
%
% Outputs:
%   cycles: Array of cycle numbers
%   active_nodes: Number of active regular nodes at each cycle
%   T1: Lifetime to first regular node death
%   energy_at_T1: Energy vector at T1 (regular nodes only)
%   ch_x, ch_y: Positions of special CHs

% Create 5 special CHs uniformly distributed on circle of radius R
num_special_ch = 5;
E_special = 4;  % 4 joules for special nodes
angles = linspace(0, 2*pi, num_special_ch + 1);
angles = angles(1:end-1);  % Remove duplicate at 2*pi

ch_x = sink_x + R * cos(angles');
ch_y = sink_y + R * sin(angles');

% Initialize energy
energy_regular = E_init * ones(N, 1);  % Regular nodes
energy_ch = E_special * ones(num_special_ch, 1);  % Special CHs

is_alive_regular = true(N, 1);
is_alive_ch = true(num_special_ch, 1);

% Assign each regular node to nearest special CH (fixed assignment)
clusters = assign_to_special_clusters(nodes_x, nodes_y, ch_x, ch_y);

% Storage for results
cycles = [];
active_nodes = [];
cycle = 0;
T1 = -1;
energy_at_T1 = [];
first_death_recorded = false;

% Main simulation loop
while sum(is_alive_regular) > 0 && sum(is_alive_ch) > 0
    cycle = cycle + 1;
    
    % Energy consumption for this cycle
    
    % Process each special CH
    for ch_idx = 1:num_special_ch
        if ~is_alive_ch(ch_idx)
            continue;
        end
        
        % 1. Receive data from cluster members
        members = find(clusters == ch_idx & is_alive_regular);
        
        for m = members'
            % Receive overhead packet from member
            E_rx = overhead_packet_size * E_elec;
            energy_ch(ch_idx) = energy_ch(ch_idx) - E_rx;
        end
        
        % 2. Aggregate data
        num_signals = length(members);  % Only from members (CH doesn't sense)
        if num_signals > 0
            E_aggregation = data_packet_size * E_agg * num_signals;
            energy_ch(ch_idx) = energy_ch(ch_idx) - E_aggregation;
        end
        
        % 3. Transmit aggregated data to sink (only if there's data)
        if num_signals > 0
            dist_to_sink = sqrt((ch_x(ch_idx) - sink_x)^2 + (ch_y(ch_idx) - sink_y)^2);
            E_tx = transmit_energy_special(data_packet_size, dist_to_sink, ...
                E_elec, eps_amp_short, eps_amp_long, d0);
            energy_ch(ch_idx) = energy_ch(ch_idx) - E_tx;
        end
        
        % Check if CH died
        if energy_ch(ch_idx) <= 0
            is_alive_ch(ch_idx) = false;
            energy_ch(ch_idx) = 0;
        end
    end
    
    % Process each regular node
    for i = 1:N
        if ~is_alive_regular(i)
            continue;
        end
        
        % Send data to assigned CH
        ch_idx = clusters(i);
        if is_alive_ch(ch_idx)
            dist_to_ch = sqrt((nodes_x(i) - ch_x(ch_idx))^2 + ...
                              (nodes_y(i) - ch_y(ch_idx))^2);
            E_tx = transmit_energy_special(overhead_packet_size, dist_to_ch, ...
                E_elec, eps_amp_short, eps_amp_long, d0);
            energy_regular(i) = energy_regular(i) - E_tx;
        else
            % CH is dead, try to find another alive CH
            min_dist = inf;
            new_ch = -1;
            for ch = 1:num_special_ch
                if is_alive_ch(ch)
                    dist = sqrt((nodes_x(i) - ch_x(ch))^2 + (nodes_y(i) - ch_y(ch))^2);
                    if dist < min_dist
                        min_dist = dist;
                        new_ch = ch;
                    end
                end
            end
            
            if new_ch > 0
                clusters(i) = new_ch;
                E_tx = transmit_energy_special(overhead_packet_size, min_dist, ...
                    E_elec, eps_amp_short, eps_amp_long, d0);
                energy_regular(i) = energy_regular(i) - E_tx;
            end
        end
        
        % Check if node died
        if energy_regular(i) <= 0
            is_alive_regular(i) = false;
            energy_regular(i) = 0;
        end
    end
    
    % Record statistics (only regular nodes)
    cycles(end+1) = cycle;
    active_nodes(end+1) = sum(is_alive_regular);
    
    % Record first regular node death
    if ~first_death_recorded && sum(is_alive_regular) < N
        T1 = cycle;
        energy_at_T1 = energy_regular;
        first_death_recorded = true;
    end
    
    % Safety check
    if cycle > 10000
        break;
    end
end

% If no node died
if T1 == -1
    T1 = cycle;
    energy_at_T1 = energy_regular;
end

end


function clusters = assign_to_special_clusters(nodes_x, nodes_y, ch_x, ch_y)
% ASSIGN_TO_SPECIAL_CLUSTERS Assigns each node to nearest special CH
%
% Outputs:
%   clusters: Vector where clusters(i) is the CH index for node i

N = length(nodes_x);
num_ch = length(ch_x);
clusters = zeros(N, 1);

for i = 1:N
    % Calculate distance to each CH
    min_dist = inf;
    nearest_ch = 1;
    
    for ch = 1:num_ch
        dist = sqrt((nodes_x(i) - ch_x(ch))^2 + (nodes_y(i) - ch_y(ch))^2);
        if dist < min_dist
            min_dist = dist;
            nearest_ch = ch;
        end
    end
    
    clusters(i) = nearest_ch;
end

end


function E_tx = transmit_energy_special(packet_size, distance, E_elec, ...
    eps_amp_short, eps_amp_long, d0)
% TRANSMIT_ENERGY_SPECIAL Calculates transmission energy
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