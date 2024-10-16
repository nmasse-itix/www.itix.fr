# Expected end time (in minutes) for each exercise
exercise_timing = [ 55, 85, 130 ];

# Counting parameters for each of the 3 exercises
# - a1, a2, a3: time bonus for each set of 5 minutes passing
# - b1, b2, b3: time bonus for each completed exercise
# - r1, r2, r3: time reference for each exercise (counted in "set of 5 minutes")
# - z1, z2, z3: time penalty for each set of 5 minutes late according to the reference time rX for the exercise
counting_params = { 1, 2, 3, 55, 25, 29, num2cell(exercise_timing / 5){:}, 1, 2, 3 };

# Time resolution (5 minutes)
step = 5;

# The timeframe to graph (2h30m)
timeframe = [ 0, 150 ];

# Time vector
t = [ timeframe(1) : step : timeframe(2) ];

# Defines a counting mechanism with a time bonus
function y = count_with_time (student_params, counting_params, step, timeframe)
  # Timing variables
  [ t0, t1, t2, t3, tmax ] = num2cell(idivide(int32 ([ timeframe(1), student_params, timeframe(2) ]), step)){:};

  # Counting weights
  a0 = 0;
  [a1, a2, a3, b1, b2, b3, r1, r2, r3, z1, z2, z3] = counting_params{:};

  y = [ timeframe(1) : step : timeframe(2) ] * 0;
  val = 0;
  for i = 1:length(y)
    tx = i - 1;
    if (tx == t1)
	  val += b1 + (r1 - tx) * z1;
	elseif (tx == t2)
	  val += b2 + (r2 - tx) * z2;
	elseif (tx == t3)
	  val += b3 + (r3 - tx) * z3;
	elseif (tx > t3)
	  val += a3;
	elseif (tx > t2)
	  val += a2;
	elseif (tx > t1)
	  val += a1;
	elseif (tx > t0)
      val += a0;
	else
	endif
	y(i) = val;
  endfor
endfunction

# Unit tests
y = count_with_time([55, 85, 130], counting_params, step, timeframe)
y = count_with_time([50, 75, 115], counting_params, step, timeframe)
y = count_with_time([60, 95, 145], counting_params, step, timeframe)

# Graph parameters
figure(1);
clf(1);
set(1, "defaulttextfontsize", 8);
set(1, "defaultaxesfontsize", 4);
xlabel("time");
ylabel("points");
title("Points awarded for each exercise with both a time bonus and an accelerator");
xlim([0 150]);
ylim([0 165]);

# There will be multiple series on the same figure
hold on;

# End-of-exercise markers
line("xdata", [ 55, 55 ], "ydata", [ 0, 165 ], "linewidth", 2, "linestyle", "--", "color", "#777777");
text(55,0, "Expected end of  \nexercise Hero  ", "rotation", 90, "horizontalalignment", "right", "fontsize", 3, "fontunits", "points");
line("xdata", [ 85, 85 ], "ydata", [ 0, 165 ], "linewidth", 2, "linestyle", "--", "color", "#777777");
text(85,0, "Expected end of  \nexercise Villain  ", "rotation", 90, "horizontalalignment", "right", "fontsize", 3, "fontunits", "points");
line("xdata", [ 130, 130 ], "ydata", [ 0, 165 ], "linewidth", 2, "linestyle", "--", "color", "#777777");
text(130,0, "Expected end of  \nexercise Fight  ", "rotation", 90, "horizontalalignment", "right", "fontsize", 3, "fontunits", "points");

# Linear progression (for reference)
l1 = plot(t, t, "-;Linear progression: 1 point per minute;", "linewidth", 2);

# on-time user
y = count_with_time([55, 85, 130], counting_params, step, timeframe);
l2 = plot (t, y, "-;normal user;", "linewidth", 4);

# early user
y = count_with_time([50, 75, 115], counting_params, step, timeframe);
l3 = plot (t, y, "-;early user;", "linewidth", 4);

# late user
y = count_with_time([60, 95, 145], counting_params, step, timeframe);
l4 = plot (t, y, "-;late user;", "linewidth", 4);

# Set axes line width
set(gca, "linewidth", 2)

# End of multiple series on the same figure
hold off;

# Legende
legend([l1, l2, l3, l4], "location", "northwest", "fontsize", 5, "fontunits", "points");

# Save figure as PNG file
print(gcf, "counting-scheme-with-time.tmp.png", "-dpng", "-S4096,2160");

# Add an alpha channel and remove the white background (requires GraphicsMagick)
system('gm convert counting-scheme-with-time.tmp.png -transparent white counting-scheme-with-time.png');
