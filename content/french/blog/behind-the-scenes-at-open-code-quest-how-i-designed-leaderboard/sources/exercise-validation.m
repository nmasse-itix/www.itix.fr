# Data to plot
t                  = [ 1 : 1 : 10 ];
service_deployed   = [ 0, 0, 0, 0, 0, 0, 1, 1, 1, 1 ];
db_deployed        = [ 0, 0, 0, 1, 1, 1, 1, 1, 1, 1 ];
pipeline_finished  = [ 0, 0, 0, 0, 1, 1, 1, 1, 1, 1 ];
exercise_completed = [ 0, 0, 0, 0, 0, 0, 1, 1, 1, 1 ];

# Logic timing diagram
figure(1);
clf(1);

# Plot 1
subplot(4, 1, 1);
set(1, "defaulttextfontsize", 8);
set(1, "defaultaxesfontsize", 4);
stairs(t, db_deployed, "-", "linewidth", 4);
axis("on", "tight");
xticks([0]);
yticks([0 1]);
ylabel("state");
title("Pod named 'hero-database-1' in state 'Running'");
set(gca, "linewidth", 2)

# Plot 2
subplot (4, 1, 2);
set(1, "defaulttextfontsize", 8);
set(1, "defaultaxesfontsize", 4);
stairs(t, pipeline_finished, "-", "linewidth", 4);
axis("on", "tight");
xticks([0]);
yticks([0 1]);
ylabel("state");
title("Tekton pipeline named 'hero' in state 'Completed'");
set(gca, "linewidth", 2)

# Plot 3
subplot(4, 1, 3);
set(1, "defaulttextfontsize", 8);
set(1, "defaultaxesfontsize", 4);
stairs(t, service_deployed, "-", "linewidth", 4);
axis("on", "tight");
xticks([0]);
yticks([0 1]);
ylabel("state");
title("Deployment named 'hero' in state 'Available'");
set(gca, "linewidth", 2)

# Plot 4
subplot(4, 1, 4);
set(1, "defaulttextfontsize", 8);
set(1, "defaultaxesfontsize", 4);
stairs(t, exercise_completed, "-", "linewidth", 4);
axis("on", "tight");
xticks([0]);
yticks([0 1]);
xlabel("time");
ylabel("state");
title("Exercise 'hero' completed");
set(gca, "linewidth", 2)

# Save figure as PNG file
print(gcf, "exercise-validation.tmp.png", "-dpng", "-S4096,2160");

# Add an alpha channel and remove the white background (requires GraphicsMagick)
system('gm convert exercise-validation.tmp.png -transparent white exercise-validation.png');
