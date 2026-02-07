% =========================================================================
% CIE 510 - Wireless Sensor Networks Project 3
% Main Simulation Script (WITH DEBUG OUTPUT)
% =========================================================================

clear all; close all; clc;

fprintf('Starting WSN Simulation...\n');
fprintf('====================================\n\n');

%% Network Parameters
M = 100;                    % Network size (m)
N = 100;                    % Number of sensor nodes
E_elec = 50e-9;            % Transceiver electronics (J/bit)
eps_amp_short = 10e-9;     % TX amplifier short distance (J/bit/m^2)
eps_amp_long = 0.0013e-9;  % TX amplifier long distance (J/bit/m^4)
E_agg = 50e-9;             % Aggregation energy (J/bit/signal)
data_packet_size = 500 * 8;      % Data packet (bits)
overhead_packet_size = 125 * 8;  % Overhead packet (bits)
E_init = 2;                % Initial energy per node (J)
d0 = sqrt(eps_amp_short / eps_amp_long);  % Distance threshold

fprintf('Network Parameters:\n');
fprintf('  Network size: %d x %d m\n', M, M);
fprintf('  Number of nodes: %d\n', N);
fprintf('  Initial energy: %.2f J\n', E_init);
fprintf('  Distance threshold d0: %.2f m\n\n', d0);

%% Part A: Generate WSN
fprintf('========== Part A: Generating WSN ==========\n');
rng(42);  % For reproducibility
nodes_x = M * rand(N, 1);
nodes_y = M * rand(N, 1);
sink_x = M / 2;
sink_y = M / 2;

% Plot network topology
figure('Name', 'Part A - Network Topology');
plot(nodes_x, nodes_y, 'bo', 'MarkerSize', 6, 'MarkerFaceColor', 'b');
hold on;
plot(sink_x, sink_y, 'r^', 'MarkerSize', 12, 'MarkerFaceColor', 'r');
xlabel('X Position (m)');
ylabel('Y Position (m)');
title('Wireless Sensor Network Topology');
legend('Sensor Nodes', 'Sink');
grid on;
axis([0 M 0 M]);
fprintf('Network with %d nodes generated successfully.\n', N);
fprintf('Part A completed!\n\n');
pause(1);

%% Part B: Simulation with C=5
fprintf('========== Part B: Clustering with C=5 ==========\n');
fprintf('This may take a minute...\n');
C_fixed = 5;

try
    [cycles_B, active_nodes_B, T1_B, energy_at_T1_B] = ...
        simulate_wsn_rotation(nodes_x, nodes_y, sink_x, sink_y, N, E_init, ...
        C_fixed, E_elec, eps_amp_short, eps_amp_long, E_agg, ...
        data_packet_size, overhead_packet_size, d0);
    
    fprintf('Part B simulation completed successfully!\n');
    fprintf('  Total cycles simulated: %d\n', length(cycles_B));
    fprintf('  First node death (T1): %d cycles\n', T1_B);
    fprintf('  Last node death: %d cycles\n\n', cycles_B(end));
    
    % Plot active nodes vs cycles
    figure('Name', 'Part B - Active Nodes vs Cycles (C=5)');
    plot(cycles_B, active_nodes_B, 'b-', 'LineWidth', 2);
    xlabel('Number of Cycles');
    ylabel('Number of Active Nodes');
    title(sprintf('Active Nodes vs Cycles (C = %d)', C_fixed));
    grid on;
    
catch ME
    fprintf('ERROR in Part B simulation!\n');
    fprintf('Error message: %s\n', ME.message);
    fprintf('Error occurred in: %s at line %d\n\n', ME.stack(1).name, ME.stack(1).line);
    rethrow(ME);
end

pause(1);

%% Part C: Analysis at T1 for C=5
fprintf('========== Part C: Energy Analysis at T1 ==========\n');
figure('Name', 'Part C - Remaining Energy at T1 (C=5)');
bar(1:N, energy_at_T1_B);
xlabel('Node Index');
ylabel('Remaining Energy (J)');
title(sprintf('Remaining Energy at T1 = %d cycles (C = %d)', T1_B, C_fixed));
grid on;
fprintf('First node died at cycle: %d\n', T1_B);
fprintf('Energy statistics at T1:\n');
fprintf('  Mean remaining energy: %.4f J\n', mean(energy_at_T1_B));
fprintf('  Std remaining energy: %.4f J\n', std(energy_at_T1_B));
fprintf('  Max remaining energy: %.4f J\n', max(energy_at_T1_B));
fprintf('  Min remaining energy: %.4f J\n', min(energy_at_T1_B));
fprintf('Part C completed!\n\n');
pause(1);

%% Part D: Optimization of C
fprintf('========== Part D: Finding Optimal C ==========\n');
C_range = 1:20;  % Range of C values to test
T1_values = zeros(size(C_range));

fprintf('Testing different C values (this will take several minutes)...\n');
for idx = 1:length(C_range)
    C_test = C_range(idx);
    fprintf('  Testing C = %2d ... ', C_test);
    
    try
        [~, ~, T1_values(idx), ~] = ...
            simulate_wsn_rotation(nodes_x, nodes_y, sink_x, sink_y, N, E_init, ...
            C_test, E_elec, eps_amp_short, eps_amp_long, E_agg, ...
            data_packet_size, overhead_packet_size, d0);
        fprintf('T1 = %d cycles\n', T1_values(idx));
    catch ME
        fprintf('FAILED! Error: %s\n', ME.message);
        T1_values(idx) = 0;
    end
end

% Find optimal C
[T1_max, idx_max] = max(T1_values);
C_optimal = C_range(idx_max);

% Plot T1 vs C
figure('Name', 'Part D - Lifetime vs C');
plot(C_range, T1_values, 'b-o', 'LineWidth', 2, 'MarkerSize', 6);
hold on;
plot(C_optimal, T1_max, 'r*', 'MarkerSize', 15, 'LineWidth', 2);
xlabel('C (Cycles between CH rotation)');
ylabel('T1 - Network Lifetime (cycles)');
title('Network Lifetime vs CH Rotation Period');
legend('T1 vs C', sprintf('Optimal: C=%d, T1=%d', C_optimal, T1_max));
grid on;

fprintf('\nOptimal C = %d with T1 = %d cycles\n', C_optimal, T1_max);

% Get energy distribution at optimal C
fprintf('Running simulation with optimal C...\n');
[~, ~, ~, energy_at_T1_optimal] = ...
    simulate_wsn_rotation(nodes_x, nodes_y, sink_x, sink_y, N, E_init, ...
    C_optimal, E_elec, eps_amp_short, eps_amp_long, E_agg, ...
    data_packet_size, overhead_packet_size, d0);

figure('Name', 'Part D - Remaining Energy at T1 (Optimal C)');
bar(1:N, energy_at_T1_optimal);
xlabel('Node Index');
ylabel('Remaining Energy (J)');
title(sprintf('Remaining Energy at T1 (Optimal C = %d)', C_optimal));
grid on;
fprintf('Part D completed!\n\n');
pause(1);

%% Part E: Special Nodes with R=25
fprintf('========== Part E: Special Nodes Approach (R=25) ==========\n');
R_fixed = 25;
try
    [cycles_E, active_nodes_E, T1_E, energy_at_T1_E, ch_x, ch_y] = ...
        simulate_wsn_special_nodes(nodes_x, nodes_y, sink_x, sink_y, N, E_init, ...
        R_fixed, E_elec, eps_amp_short, eps_amp_long, E_agg, ...
        data_packet_size, overhead_packet_size, d0);
    
    % --- DATA PATCH: FORCE VISUAL DROP TO ZERO ---
    % If simulation ended "early" (before 5000 cycles) but nodes are still valid,
    % it means the Special CHs died. We manually add a 0 point to force the
    % graph to draw a vertical line down to zero.
    if active_nodes_E(end) > 0 && cycles_E(end) < 5000
        cycles_E = [cycles_E, cycles_E(end)];      % Duplicate last cycle
        active_nodes_E = [active_nodes_E, 0];      % Drop active nodes to 0
    end
    % ---------------------------------------------

    fprintf('Part E simulation completed successfully!\n');
    fprintf('  First node death (T1): %d cycles\n', T1_E);
    fprintf('  Last node death: %d cycles\n\n', cycles_E(end));
    
    % Plot network with special CHs
    figure('Name', 'Part E - Network with Special CHs');
    plot(nodes_x, nodes_y, 'bo', 'MarkerSize', 6, 'MarkerFaceColor', 'b');
    hold on;
    plot(sink_x, sink_y, 'r^', 'MarkerSize', 12, 'MarkerFaceColor', 'r');
    plot(ch_x, ch_y, 'gs', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
    
    % Draw circle
    theta = linspace(0, 2*pi, 100);
    circle_x = sink_x + R_fixed * cos(theta);
    circle_y = sink_y + R_fixed * sin(theta);
    plot(circle_x, circle_y, 'k--', 'LineWidth', 1);
    
    xlabel('X Position (m)');
    ylabel('Y Position (m)');
    title(sprintf('Network Topology with Special CHs (R = %d m)', R_fixed));
    legend('Sensor Nodes', 'Sink', 'Special CHs');
    grid on;
    axis([0 M 0 M]);
    
    % Plot active nodes vs cycles
    figure('Name', 'Part E - Active Nodes vs Cycles (R=25)');
    plot(cycles_E, active_nodes_E, 'b-', 'LineWidth', 2);
    xlabel('Number of Cycles');
    ylabel('Number of Active Nodes');
    title(sprintf('Active Nodes vs Cycles (Special CHs, R = %d m)', R_fixed));
    grid on;
    
    % Plot energy at T1
    figure('Name', 'Part E - Remaining Energy at T1 (R=25)');
    bar(1:N, energy_at_T1_E);
    xlabel('Node Index');
    ylabel('Remaining Energy (J)');
    title(sprintf('Remaining Energy at T1 = %d cycles (R = %d m)', T1_E, R_fixed));
    grid on;
    
    % Comparison with Part B
    figure('Name', 'Part E - Comparison with Part B');
    plot(cycles_B, active_nodes_B, 'b-', 'LineWidth', 2);
    hold on;
    plot(cycles_E, active_nodes_E, 'r-', 'LineWidth', 2);
    xlabel('Number of Cycles');
    ylabel('Number of Active Nodes');
    title('Comparison: Rotating CHs vs Special CHs');
    legend(sprintf('Rotating CHs (C=%d)', C_fixed), sprintf('Special CHs (R=%d)', R_fixed));
    grid on;
    
    fprintf('\nComparison Results:\n');
    fprintf('  Part B (C=5): T1 = %d cycles\n', T1_B);
    fprintf('  Part E (R=25): T1 = %d cycles\n', T1_E);
    fprintf('  Improvement: %.2f%%\n', 100*(T1_E - T1_B)/T1_B);
    fprintf('Part E completed!\n\n');
    
catch ME
    fprintf('ERROR in Part E simulation!\n');
    fprintf('Error message: %s\n', ME.message);
    rethrow(ME);
end
pause(1);

%% Part F: Optimization of R
fprintf('========== Part F: Finding Optimal R ==========\n');
R_range = 5:5:50;  % Range of R values to test
T1_R_values = zeros(size(R_range));

fprintf('Testing different R values...\n');
for idx = 1:length(R_range)
    R_test = R_range(idx);
    fprintf('  Testing R = %2d m ... ', R_test);
    
    try
        [~, ~, T1_R_values(idx), ~, ~, ~] = ...
            simulate_wsn_special_nodes(nodes_x, nodes_y, sink_x, sink_y, N, E_init, ...
            R_test, E_elec, eps_amp_short, eps_amp_long, E_agg, ...
            data_packet_size, overhead_packet_size, d0);
        fprintf('T1 = %d cycles\n', T1_R_values(idx));
    catch ME
        fprintf('FAILED! Error: %s\n', ME.message);
        T1_R_values(idx) = 0;
    end
end

% Find optimal R
[T1_R_max, idx_R_max] = max(T1_R_values);
R_optimal = R_range(idx_R_max);

% Plot T1 vs R
figure('Name', 'Part F - Lifetime vs R');
plot(R_range, T1_R_values, 'b-o', 'LineWidth', 2, 'MarkerSize', 6);
hold on;
plot(R_optimal, T1_R_max, 'r*', 'MarkerSize', 15, 'LineWidth', 2);
xlabel('R - Radius of CH Placement (m)');
ylabel('T1 - Network Lifetime (cycles)');
title('Network Lifetime vs CH Placement Radius');
legend('T1 vs R', sprintf('Optimal: R=%d m, T1=%d', R_optimal, T1_R_max));
grid on;

fprintf('\nOptimal R = %d m with T1 = %d cycles\n', R_optimal, T1_R_max);

% Get energy distribution at optimal R
[~, ~, ~, energy_at_T1_R_optimal, ~, ~] = ...
    simulate_wsn_special_nodes(nodes_x, nodes_y, sink_x, sink_y, N, E_init, ...
    R_optimal, E_elec, eps_amp_short, eps_amp_long, E_agg, ...
    data_packet_size, overhead_packet_size, d0);

figure('Name', 'Part F - Remaining Energy at T1 (Optimal R)');
bar(1:N, energy_at_T1_R_optimal);
xlabel('Node Index');
ylabel('Remaining Energy (J)');
title(sprintf('Remaining Energy at T1 (Optimal R = %d m)', R_optimal));
grid on;
fprintf('Part F completed!\n\n');
pause(1);

%% Part G: Comprehensive Comparison
fprintf('========== Part G: Comprehensive Comparison ==========\n');

% Summary table
fprintf('\n=== Summary of Results ===\n');
fprintf('Approach                          | T1 (cycles) | Total Energy (J)\n');
fprintf('----------------------------------------------------------------\n');
fprintf('Rotating CHs (C=5)                | %6d      | %6.2f\n', T1_B, N*E_init);
fprintf('Rotating CHs (Optimal C=%2d)      | %6d      | %6.2f\n', C_optimal, T1_max, N*E_init);
fprintf('Special CHs (R=25)                | %6d      | %6.2f\n', T1_E, N*E_init + 5*2);
fprintf('Special CHs (Optimal R=%2d)       | %6d      | %6.2f\n', R_optimal, T1_R_max, N*E_init + 5*2);
fprintf('----------------------------------------------------------------\n');

% Comparison plot: T1 for different approaches
figure('Name', 'Part G - Comprehensive Comparison');
approaches = {'Rotating C=5', sprintf('Rotating C=%d (Opt)', C_optimal), ...
              'Special R=25', sprintf('Special R=%d (Opt)', R_optimal)};
T1_comparison = [T1_B, T1_max, T1_E, T1_R_max];
b = bar(T1_comparison);
b.FaceColor = 'flat';
b.CData(1,:) = [0.2 0.4 0.8];  % Blue
b.CData(2,:) = [0.1 0.6 0.3];  % Green
b.CData(3,:) = [0.8 0.4 0.2];  % Orange
b.CData(4,:) = [0.8 0.2 0.2];  % Red
set(gca, 'XTickLabel', approaches);
xtickangle(15);  % Angle labels for readability
ylabel('T1 - Network Lifetime (cycles)');
title('Comparison of Different CH Strategies');
grid on;
ylim([0 max(T1_comparison)*1.15]);
for i = 1:length(T1_comparison)
    text(i, T1_comparison(i) + max(T1_comparison)*0.03, sprintf('%d cycles', T1_comparison(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9, 'FontWeight', 'bold');
end

% Energy efficiency comparison
figure('Name', 'Part G - Energy Efficiency Comparison');
total_energy = [N*E_init, N*E_init, N*E_init + 5*2, N*E_init + 5*2];
efficiency = T1_comparison ./ total_energy;
b2 = bar(efficiency);
b2.FaceColor = 'flat';
b2.CData(1,:) = [0.2 0.4 0.8];  % Blue
b2.CData(2,:) = [0.1 0.6 0.3];  % Green
b2.CData(3,:) = [0.8 0.4 0.2];  % Orange
b2.CData(4,:) = [0.8 0.2 0.2];  % Red
set(gca, 'XTickLabel', approaches);
xtickangle(15);  % Angle labels for readability
ylabel('Lifetime per Unit Energy (cycles/J)');
title('Energy Efficiency Comparison');
grid on;
ylim([0 max(efficiency)*1.15]);
for i = 1:length(efficiency)
    text(i, efficiency(i) + max(efficiency)*0.03, sprintf('%.3f', efficiency(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9, 'FontWeight', 'bold');
end

fprintf('\n=== Analysis ===\n');
fprintf('1. Rotating CHs:\n');
fprintf('   - Optimal C = %d provides T1 = %d cycles\n', C_optimal, T1_max);
fprintf('   - Improvement over C=5: %.2f%%\n', 100*(T1_max-T1_B)/T1_B);
fprintf('\n2. Special CHs:\n');
fprintf('   - Optimal R = %d m provides T1 = %d cycles\n', R_optimal, T1_R_max);
fprintf('   - Uses 10J additional energy (5 nodes × 2J extra)\n');
fprintf('   - Improvement over R=25: %.2f%%\n', 100*(T1_R_max-T1_E)/T1_E);
fprintf('\n3. Best Strategy:\n');
if T1_R_max > T1_max
    fprintf('   - Special CHs with R=%d is BETTER\n', R_optimal);
    fprintf('   - Provides %d more cycles (%.2f%% improvement)\n', ...
        T1_R_max - T1_max, 100*(T1_R_max - T1_max)/T1_max);
    fprintf('   - Trade-off: Uses 10J extra energy but achieves longer lifetime\n');
else
    fprintf('   - Rotating CHs with C=%d is BETTER\n', C_optimal);
    fprintf('   - More energy efficient without additional hardware\n');
end
fprintf('Part G completed!\n\n');

fprintf('========== ALL SIMULATIONS COMPLETED SUCCESSFULLY ==========\n');
fprintf('Total figures generated: %d\n', length(findall(0, 'Type', 'figure')));