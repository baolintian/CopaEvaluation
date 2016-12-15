#!/bin/bash

link_rate=12 # (mbps)
min_delay=25 # Two way delay in ms
queue_length=`expr 2 \* $min_delay \* $link_rate \* 1000 / 8`
output_directory=LossyLink
nsrc=1
on_duration=60000 # (ms)
rat_file=../evaluations/rats/fig2-linkspeed/bigbertha-100x.dna.5

if [[ ! -d $output_directory ]]; then
		mkdir $output_directory
fi

if [[ $1 == "run" ]]; then
		for (( i = 0; i < 11; i=i+1 )); do
				loss_rate=`awk -v i=$i 'END{if(i < 5)print i * 0.2; else print (i-4) * 1.0}' /dev/null`
				echo "Running on loss rate = $loss_rate"
				
				for cc_type in "markovian" "cubic" "reno" "pcc"; do
            tcp_dir=$output_directory/$cc_type::$loss_rate
            if [[ -d $tcp_dir ]]; then
                continue
            fi
						runstr="sudo ./long-run-qdisc.sh run $cc_type $link_rate $min_delay $loss_rate $output_directory $nsrc:continuous $queue_length $on_duration $rat_file"
						echo $runstr
						$runstr
						mv $output_directory/$cc_type $tcp_dir
				done
		done

elif [[ $1 == "graph" ]]; then
		if [[ -d $output_directory/graphdir ]]; then
				trash $output_directory/graphdir
		fi
		mkdir $output_directory/graphdir

		for tcp_dir in $output_directory/*::*; do
				tcp=`expr "$tcp_dir" : ".*/\([^/]*\)::[0-9.]*"`
				loss_rate=`expr "$tcp_dir" : ".*::\([0-9.]*\)"`
				
				# Gather statistics
        tpt=`grep throughput $tcp_dir/$tcp.pcap-trace | awk '{if ($2 > cur) cur=$2; if ($5 > cur) cur=$5;} END{print 1e-6*8*cur}'`
				#throughput=`grep throughput $tcp_dir/$tcp.pcap-trace | awk -F ' ' '{print $3}'`
				echo $loss_rate $tpt >>$output_directory/graphdir/$tcp.dat
		done

		# Create gnuplot script
		gnuplot_script="set xlabel 'Loss %'; set ylabel 'Throughput (Mbps)';
    set terminal svg fsize 14; set output '$output_directory/graphdir/loss-tpt.svg'; 
    plot " >>$output_directory/graphdir/loss-tpt.gnuplot
		for tcp in $output_directory/graphdir/*.dat; do
				tcp_nice=`expr "$tcp" : ".*/\([^/]*\).dat"`
				echo $tcp $tcp_nice
				gnuplot_script="$gnuplot_script '$tcp' using 1:2 title '$tcp_nice' with lines, "
		done
		echo $gnuplot_script >$output_directory/graphdir/loss-tpt.gnuplot
	
		gnuplot -p $output_directory/graphdir/loss-tpt.gnuplot
		inkscape --export-png=$output_directory/graphdir/loss-tpt.png -b '#ffffff' -D $output_directory/graphdir/loss-tpt.svg
		display $output_directory/graphdir/loss-tpt.png

elif [[ $1 == "clean" ]]; then
		trash $output_directory

else
		echo "Unrecognized command '$1'."
		echo "   Expected one of [run|graph|clean]"
fi