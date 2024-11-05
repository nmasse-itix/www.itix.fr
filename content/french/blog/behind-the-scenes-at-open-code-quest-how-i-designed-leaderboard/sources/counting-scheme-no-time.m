# Defines a basic counting mechanism with no time bonus
exercise_timing = [ 55, 85, 130 ];
counting_params = [ 0, 0, 0; 55, 30, 45 ];
step = 5;
timeframe = [ 0, 150 ];
t = [ timeframe(1) : step : timeframe(2) ];
function y = count_basic (student_params, counting_params, step, timeframe)
  # Timing variables
  t0 = idivide(int32 (timeframe(1)), step);
  t1 = idivide(int32 (student_params(1)), step);
  t2 = idivide(int32 (student_params(2)), step);
  t3 = idivide(int32 (student_params(3)), step);
  tmax = idivide(int32 (timeframe(2)), step);

  # Counting weights
  p1 = counting_params(2, 1);
  p2 = counting_params(2, 2);
  p3 = counting_params(2, 3);

  y = [ timeframe(1) : step : timeframe(2) ] * 0;
  val = 0;
  for i = 1:length(y)
    tx = i - 1;
    if (tx == t1)
	  val += p1;
	elseif (tx == t2)
	  val += p2;
	elseif (tx == t3)
	  val += p3;
	else
	endif
	y(i) = val;
  endfor
endfunction

# Unit tests
count_basic([55, 85, 130], counting_params, step, timeframe)
count_basic([50, 75, 115], counting_params, step, timeframe)
count_basic([60, 95, 145], counting_params, step, timeframe)

# Graph parameters
figure(1);
clf(1);
set(1, "defaulttextfontsize", 8);
set(1, "defaultaxesfontsize", 4);
xlabel("time");
ylabel("points");
title("Points awarded for each exercise without taking time into account");
xlim([0 150]);
ylim([0 150]);

# There will be multiple series on the same figure
hold on;

# End-of-exercise markers
line("xdata", [ 55, 55 ], "ydata", [ 0, 130 ], "linewidth", 2, "linestyle", "--", "color", "#777777");
text(55,0, "Expected end of  \nexercise Hero  ", "rotation", 90, "horizontalalignment", "right", "fontsize", 3, "fontunits", "points");
line("xdata", [ 85, 85 ], "ydata", [ 0, 130 ], "linewidth", 2, "linestyle", "--", "color", "#777777");
text(85,0, "Expected end of  \nexercise Villain  ", "rotation", 90, "horizontalalignment", "right", "fontsize", 3, "fontunits", "points");
line("xdata", [ 130, 130 ], "ydata", [ 0, 130 ], "linewidth", 2, "linestyle", "--", "color", "#777777");
text(130,0, "Expected end of  \nexercise Fight  ", "rotation", 90, "horizontalalignment", "right", "fontsize", 3, "fontunits", "points");

# Linear progression (for reference)
l1 = plot(t, t, "-;Linear progression: 1 point per minute;", "linewidth", 2);

# on-time user
y = count_basic([55, 85, 130], counting_params, step, timeframe);
l2 = plot(t, y, "-;normal user;", "linewidth", 4);

# early user
y = count_basic([50, 75, 115], counting_params, step, timeframe);
l3 = plot(t, y, "-;early user;", "linewidth", 4);

# late user
y = count_basic([60, 95, 145], counting_params, step, timeframe);
l4 = plot(t, y, "-;late user;", "linewidth", 4);

# Set axes line width
set(gca, "linewidth", 2)

# End of multiple series on the same figure
hold off;

# Legend
legend([l1, l2, l3, l4], "location", "northwest", "fontsize", 5, "fontunits", "points");

# Save figure as PNG file
print(gcf, "counting-scheme-no-time.tmp.png", "-dpng", "-S4096,2160");

# Add an alpha channel and remove the white background (requires GraphicsMagick)
system('gm convert counting-scheme-no-time.tmp.png -transparent white counting-scheme-no-time.png');
