package App::durseq;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

$SPEC{dateseq} = {
    v => 1.1,
    summary => 'Generate a sequence of durations',
    description => <<'_',

This utility is similar to Unix <prog:seq> command or Perl script
<prog:dateseq>, except that it generates a sequence of dates.

_
    args_rels => {
    },
    args => {
        from => {
            summary => 'Starting duration',
            schema => ['duration*', {
                'x.perl.coerce_to' => 'DateTime::Duration',
                'x.perl.coerce_rules' => ['str_iso8601'],
            }],
            pos => 0,
        },
        to => {
            summary => 'Ending duration, if not specified will generate an infinite* stream of durations',
            schema => ['duration*', {
                'x.perl.coerce_to' => 'DateTime::Duration',
                'x.perl.coerce_rules' => ['str_iso8601'],
            }],
            pos => 1,
        },
        increment => {
            summary => 'Increment, default is one day (P1D)',
            schema => ['duration*', {
                'x.perl.coerce_to' => 'DateTime::Duration',
                'x.perl.coerce_rules' => ['str_iso8601'],
            }],
            cmdline_aliases => {i=>{}},
            pos => 2,
        },
        reverse => {
            summary => 'Decrement instead of increment',
            schema => 'true*',
            cmdline_aliases => {r=>{}},
        },

        #header => {
        #    summary => 'Add a header row',
        #    schema => 'str*',
        #},
        limit => {
            summary => 'Only generate a certain amount of items',
            schema => ['int*', min=>1],
            cmdline_aliases => {n=>{}},
        },
        # XXX format_module
        # XXX format_args
    },
    examples => [
        {
            summary => 'Generate "infinite" durations from zero (then P1D, P2D, ...)',
            src => '[[prog]]',
            src_plang => 'bash',
            test => 0,
            'x.doc.show_result' => 0,
        },
        {
            summary => 'Generate durations from P0D to P10D',
            src => '[[prog]] P0D P10D',
            src_plang => 'bash',
            'x.doc.max_result_lines' => 5,
        },
        {
            summary => 'Generate durations from P0D to P10D, with 12 hours increment',
            src => '[[prog]] P0D P10D -i PT12H',
            src_plang => 'bash',
            'x.doc.max_result_lines' => 5,
        },
        {
            summary => 'Generate durations from P10D to P0D (reverse)',
            src => '[[prog]] P10D P0D -r',
            src_plang => 'bash',
            'x.doc.max_result_lines' => 5,
        },
        {
            summary => 'Generate 10 durations from P1M (increment 1 week)',
            src => '[[prog]] P1M -i P1W -n 10',
            src_plang => 'bash',
            'x.doc.max_result_lines' => 5,
        },
        #{
        #    summary => 'Generate a CSV data',
        #    src => '[[prog]] 2010-01-01 2015-01-31 -f "%Y,%m,%d" --header "year,month,day"',
        #    src_plang => 'bash',
        #    'x.doc.max_result_lines' => 5,
        #},
        #{
        #    summary => 'Use with fsql',
        #    src => q{[[prog]] 2010-01-01 2015-12-01 -f "%Y,%m" -i P1M --header "year,month" | fsql --add-csv - --add-csv data.csv -F YEAR -F MONTH 'SELECT year, month, data1 FROM stdin WHERE YEAR(data.date)=year AND MONTH(data.date)=month'},
        #    src_plang => 'bash',
        #    'x.doc.show_result' => 0,
        #},
    ],
};
sub durseq {
    require DateTime;
    require DateTime::Duration;
    require DateTime::Format::Duration::ISO8601;

    my %args = @_;

    my $base_dt = DateTime->now;

    $args{from} //= DateTime::Duration->new(days=>0);
    $args{increment} //= DateTime::Duration->new(days=>1);
    my $reverse = $args{reverse};

    #my $fmt  = $args{date_format} // do {
    #    my $has_hms;
    #    {
    #        if ($args{from}->hour || $args{from}->minute || $args{from}->second) {
    #            $has_hms++; last;
    #        }
    #        if (defined($args{to}) &&
    #                ($args{to}->hour || $args{to}->minute || $args{to}->second)) {
    #            $has_hms++; last;
    #        }
    #        if ($args{increment}->hours || $args{increment}->minutes || $args{increment}->seconds) {
    #            $has_hms++; last;
    #        }
    #    }
    #    $has_hms ? '%Y-%m-%dT%H:%M:%S' : '%Y-%m-%d';
    #};
    my $fmt_iso = DateTime::Format::Duration::ISO8601->new();

    if (defined $args{to} || defined $args{limit}) {
        my @res;
        #push @res, $args{header} if $args{header};
        my $dtdur = $args{from}->clone;
        while (1) {
            if (defined $args{to}) {
                last if !$reverse && DateTime::Duration->compare($dtdur, $args{to}, $base_dt) > 0;
                last if  $reverse && DateTime::Duration->compare($dtdur, $args{to}, $base_dt) < 0;
            }
            push @res, $fmt_iso->format_duration($dtdur);
            last if defined($args{limit}) && @res >= $args{limit};
            $dtdur = $reverse ? $dtdur - $args{increment} : $dtdur + $args{increment};
        }
        return [200, "OK", \@res];
    } else {
        # stream
        my $dtdur = $args{from}->clone;
        my $j     = $args{header} ? -1 : 0;
        my $next_dtdur;
        #my $finish;
        my $func0 = sub {
            #return undef if $finish;
            $dtdur = $next_dtdur if $j++ > 0;
            #return $args{header} if $j == 0 && $args{header};
            $next_dtdur = $reverse ?
                $dtdur - $args{increment} : $dtdur + $args{increment};
            #$finish = 1 if ...
            return $dtdur;
        };
        my $func = sub {
            while (1) {
                my $dtdur = $func0->();
                return undef unless defined $dtdur;
                #last if $code_filter->($dt);
            }
            $fmt_iso->format_duration($dtdur);
        };
        return [200, "OK", $func, {schema=>'str*', stream=>1}];
    }
}

1;
# ABSTRACT:
