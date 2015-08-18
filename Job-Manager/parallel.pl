#! /usr/bin/env perl

#require '5.18.2';

### Encoding
use utf8;
binmode STDOUT,":utf8";
use open ":utf8";
###

### Pedantic
use warnings;
use strict;
###

### Bool value
use constant TRUE=>1;
use constant FALSE=>0;
###

### Other Modules
use Time::HiRes ();
use File::chdir;
use Switch;
###

### Getting hostname
our $hostname='';
$hostname=`hostname -s`;
$hostname=~ s/[\r\n]//g;
###

### Default Commandline Arguments
my %par=(
"var" =>{
    "J" =>'0.00',
    "K" =>'0.00',
    "therm_mcs" =>10000000,
    "observe_mcs" =>10000000,
    "bottom_length" =>40,
    "seed" =>1,
    "z_length" =>220,
    "segment_number" =>200,
    "grafting_point" =>50,
    "process" =>2,
    "interval" =>'0.05',
    "start" =>'0.00',
    "end" =>'1.00',
},
"str" =>{
    "variable" =>'',
},
"bool" =>{
    "gethelp" => FALSE,
    "printpar" => FALSE,
    "nonsol" => FALSE,
    "dryrun" => FALSE,
    "correlation" => FALSE,
},
"twitter_keys" =>{
    "consumer_key" => '',
    "consumer_secret" => '',
    "token" => '',
    "token_secret" => '',
},
"environment"=>{
    "program_name"=>'sol.out',
    "hostname"=>$hostname,
},
);
my @seed;
my @bottom;
my $gethelp=FALSE;
###

### usage
sub show_help {
    my $help_doc=<<EOF;
    
Usage:
    perl $0 [options]
    
Options:
    --help                              :このスクリプトの詳細を表示
    --process           [integer]       :物理コア数
    --choose            [J or K]        :変化させるシミュレーションの変数
    --start             [float]         :変数の始まる値
    --end               [float]         :変数の終わる値
    --interval          [float]         :変数の間隔
    --seed              [integer:Array] :変化させるseedの配列
    --bottom            [integer:Array] :変化させるbottomの長さの配列
    --consumer-key      [string]        :Twitterのconsumer-key
    --consumer-secret   [string]        :Twitterのconsumer-secret-key
    --token             [string]        :Twitterのaccess-token-key
    --token-secret      [string]        :Twitterのaccess-token-secret-key
    --dry-run                           :試しに走らせてみる
    --dump                              :入力された変数をYAML形式で出力,単体でdefaultのparameterの表示
    --nonsol                            :溶媒の効果の存在の有無
    --correlation                       :溶媒と高分子鎖の相関の計算の有無
    
EOF
    return $help_doc;
}
###

### Getopt
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);

GetOptions(
'--process=i'=>\$par{'var'}{'process'},
'--choose=s'=>\$par{'str'}{'variable'},
'--start=f'=>\$par{'var'}{'start'},
'--end=f'=>\$par{'var'}{'end'},
'--interval=f'=>\$par{'var'}{'interval'},
'--seed=i{1,}'=>\@seed,
'--bottom=i{1,}'=>\@bottom,
'--help|?'=>\$par{'bool'}{'gethelp'},
'--dry-run'=>\$par{'bool'}{'dryrun'},
'--dump'=>\$par{'bool'}{'printpar'},
'--nonsol'=>\$par{'bool'}{'nonsol'},
'--correlation'=>\$par{'bool'}{'correlation'},						
'--consumer-key=s'=>\$par{'twitter_keys'}{'consumer_key'},
'--consumer-key-secret=s'=>\$par{'twitter_keys'}{'consumer_secret'},
'--token=s'=>\$par{'twitter_keys'}{'token'},
'--token-secret=s'=>\$par{'twitter_keys'}{'token_secret'},
) or die $!;

if(@seed eq ""){
    @seed=$par{'var'}{'seed'};
}
if(@bottom eq ""){
    @bottom=$par{'var'}{'bottom_length'};
}

###

### Twitter 
use Net::Twitter;

our $twtr = Net::Twitter->new(
traits => ['API::RESTv1_1'],
consumer_key => $par{'twitter_keys'}{'consumer_key'},
consumer_secret => $par{'twitter_keys'}{'consumer_secret'},
access_token =>$par{'twitter_keys'}{'token'},
access_token_secret =>$par{'twitter_keys'}{'token_secret'},
SSL => TRUE,
);

sub tweet{
    my $tweet=shift; # Equal to $_[0]
    my $update=$twtr->update($tweet);
}

sub timeline{
    my $tl=$twtr->home_timeline();
    return $tl;
}
###

### Dump
use Data::Dumper;
use YAML::XS;

sub Dump_YAML_par{
    print STDOUT YAML::XS::Dump %par;
}
###

### Generate commandline
sub gen_com{
    
    my $setdir=shift;
    my $command_par="--SL $par{'var'}{'segment_number'} --mcs $par{'var'}{'therm_mcs'} --Mz $par{'var'}{'z_length'} --SN $par{'var'}{'grafting_point'}";
    my $add_par="";
    
    if($par{'bool'}{'correlation'}==TRUE){
        $add_par=$add_par." "."--correlation";
    }
    
    if($par{'bool'}{'nonsol'}==TRUE){
        $add_par=$add_par." "."--nonsol";
    }else{
        switch($par{'str'}{'variable'}){
            case 'J'	{$add_par=$add_par." "."--K $par{'var'}{'K'} --J"}
            case 'K'	{$add_par=$add_par." "."--J $par{'var'}{'J'} --K"}
            else 		{die $!}
        } 
    }
    
    return $setdir."/".$par{'environment'}{'program_name'}." ".$command_par.$add_par;
}
###

### ForkManager
use Parallel::ForkManager;
###

### Dry-run
sub test{
    my $pm_dr = new Parallel::ForkManager($par{'var'}{'process'});
    
    $pm_dr->run_on_start(
    sub {
        my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data)=@_;
        print STDERR "** started, pid: $pid, ";
        my $data_str=localtime;
        print STDERR $data_str ."\n";
    }
    );
    
    $pm_dr->run_on_finish(
    sub {
        my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data) = @_;
        print STDERR "** just got out ".
        "with PID $pid and exit code: $exit_code, ";
        my $data_str=localtime;
        print STDERR $data_str ."\n\n";
    }
    );
    
    print(STDERR "At $hostname, Let us begin test!!\n");
    
    my $command_line=&gen_com(".");
    
    foreach my $seed (@seed){
        foreach my $bottom (@bottom){
            if($par{'bool'}{'nonsol'}==TRUE){
                if (my $pid=$pm_dr->start) {
                    Time::HiRes::sleep(0.5);
                    next;
                }
                
                $command_line="$command_line --seed $seed --M $bottom";
                $command_line="$command_line 1>nonsol_M${bottom}s${seed}.dat";
                $command_line="$command_line 2>nonsol_M${bottom}s${seed}_err.dat";
                
                print(STDOUT "At $hostname, $command_line\n");
                
                sleep(3);
                $pm_dr->finish;
            }else{
                for(my $iter=$par{'var'}{'start'};$iter<=$par{'var'}{'end'};$iter=sprintf("%.2f",$iter+$par{'var'}{'interval'})){
                    if (my $pid=$pm_dr->start) {
                        Time::HiRes::sleep(0.2);
                        next;
                    }
                    
                    $command_line="$command_line $iter --seed $seed --M $bottom";
                    
                    if($par{'str'}{'variable'} eq "J"){
                        $command_line="$command_line 1>sol_J${iter}K$par{'var'}{'K'}M${bottom}s${seed}.dat";
                        $command_line="$command_line 2>sol_J${iter}K$par{'var'}{'K'}M${bottom}s${seed}_err.dat";
                    }elsif($par{'str'}{'variable'} eq "K"){
                        $command_line="$command_line 1>sol_J$par{'var'}{'J'}K${iter}${bottom}s${seed}.dat";
                        $command_line="$command_line 2>sol_J$par{'var'}{'J'}K${iter}${bottom}s${seed}_err.dat";
                    }
                    
                    print(STDOUT "At $hostname, $command_line\n");
                    
                    sleep(3);
                    $pm_dr->finish;
                }
            }
            #Next Seed or M
        }
    }
    
    print(STDERR "Waiting Children.\n");
    $pm_dr->wait_all_children;
    
    print(STDERR "All end test at $hostname!!\n");
}
###

### Running
sub spork{
    
    print(STDERR "Start at $hostname.\n");
    
    my $pm = new Parallel::ForkManager($par{'var'}{'process'});
    
    $pm->run_on_start(
    sub {
        my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data)=@_;
        my $tw="** At $hostname, started, pid: $pid, ";
        my $data_str=localtime;
        $tw=$tw.$data_str."\n";
        tweet($tw);
        print(STDERR $tw);
    }
    );
    
    $pm->run_on_finish(
    sub {
        my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data) = @_;
        my $tw="** At $hostname, just got out ".
        "with PID $pid and exit code: $exit_code, ";
        my $data_str=localtime;
        $tw=$tw.$data_str."\n\n";
        tweet($tw);
        print(STDERR $tw);
        
    }
    );
    
    my $command_line=&gen_com(".");
    
    foreach my $seed (@seed){
        foreach my $bottom (@bottom){
            if($par{'bool'}{'nonsol'}==TRUE){
                if (my $pid=$pm->start) {
                    Time::HiRes::sleep(0.5);
                    next;
                }
                
                $command_line="$command_line --seed $seed --M $bottom";
                $command_line="$command_line 1>nonsol_M${bottom}s${seed}.dat";
                $command_line="$command_line 2>nonsol_M${bottom}s${seed}_err.dat";
                
                print(STDOUT "At $hostname, $command_line\n");
                tweet("At $hostname, $command_line");
                system($command_line);
                
                sleep(3);
                $pm->finish;
            }else{
                for(my $iter=$par{'var'}{'start'};$iter<=$par{'var'}{'end'};$iter=sprintf("%.2f",$iter+$par{'var'}{'interval'})){
                    if (my $pid=$pm->start) {
                        Time::HiRes::sleep(0.2);
                        next;
                    }
                    
                    $command_line="$command_line $iter --seed $seed --M $bottom";
                    
                    if($par{'str'}{'variable'} eq "J"){
                        $command_line="$command_line 1>sol_J${iter}K$par{'var'}{'K'}M${bottom}s${seed}.dat";
                        $command_line="$command_line 2>sol_J${iter}K$par{'var'}{'K'}M${bottom}s${seed}_err.dat";
                    }elsif($par{'str'}{'variable'} eq "K"){
                        $command_line="$command_line 1>sol_J$par{'var'}{'J'}K${iter}${bottom}s${seed}.dat";
                        $command_line="$command_line 2>sol_J$par{'var'}{'J'}K${iter}${bottom}s${seed}_err.dat";
                    }
                    
                    print(STDOUT "At $hostname, $command_line\n");
                    tweet("At $hostname, $command_line");
                    system($command_line);
                    
                    sleep(3);
                    $pm->finish;
                }
            }
            #Next Seed or M
        }
    }
    
    print(STDERR "Waiting Children.\n");
    $pm->wait_all_children;
    
    print(STDERR "All end at $hostname!!\n");
}
###

### Main
sub main{
    if($par{'bool'}{'printpar'}==TRUE){
        &Dump_YAML_par;
    }elsif($par{'bool'}{'gethelp'}==TRUE){
        print &show_help;
    }elsif($par{'bool'}{'dryrun'}==TRUE){
        &test;
    }else{
        &spork;
    }
    exit(0);
}
###

&main;









