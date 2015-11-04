#! /usr/bin/env perl

#
# Copyright 2015 Nate-River56
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
#


#require '5.18.2';

### Encoding
use utf8;
binmode STDOUT,":utf8";
use open ":utf8";
###

### Pedantic
use warnings;
use strict;
no warnings 'redefine';
###

### Bool value
use constant TRUE=>1;
use constant FALSE=>0;
###

### Other Modules
use Time::HiRes ();
use File::chdir;
use Switch;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use Net::Twitter;
use JSON::XS;
use Encode;
###

### Dumper module
use Data::Dumper;
{
    package Data::Dumper;
    sub qquote{return shift;}
}
$Data::Dumper::Useperl=TRUE;
###

### Getting hostname

###

### Default Commandline Arguments
my %par=(
	"gethelp" => FALSE,
	"read_json"=>FALSE,
    "print_yaml" => FALSE,
    "print_json" => FALSE,
    "dryrun" => FALSE,
);
###

### Default JSON value
my %json=(
	system=>{
        process=>{
            value=>2,
            comment=>"実行する時のフォークする最大数",
        },
        program=>{
            value=>'sol.s.out',
            comment=>"プログラムのファイル名",
        },
        
	},
	twitter=>{
        consumer_key=>{
            value=>$ENV{'TWTR_CONS_KEY'},
            comment=>"Twitter REST APIのコンシューマーキー",
        },
    	consumer_secret =>{
            value=>$ENV{'TWTR_CONS_SEC'},
            comment=>"",
        },
        token=>{
            value=>$ENV{'TWTR_TOKEN_KEY'},
            comment=>"",
        },
        token_secret=>{
            value=>$ENV{'TWTR_TOKEN_SEC'},
            comment=>"",
        },
	},
	simulation=>{
    	integer=>{
        	SL=>{
            	value=>200,
            	comment=>"高分子のセグメント数",
            },
            SN=>{
            	value=>50,
                comment=>"高分子鎖の植え付け本数",
            },
            Mz=>{
                value=>220,
                comment=>"Z方向の系の長さ",
            },
            M=>{
                value=>[
                	20,
                	30,
                	40,
                ],
                comment=>"xy方向の系の長さ",
            },
            seed=>{
                value=>[
                	1,
                	2,
                	3,
                ],
                comment=>"乱数のseed",
            },
            mcs=>{
                value=>10000000,
                comment=>"Monte-Carlo-Step数",
            },
    	    
    	},
    	float=>{
            J=>{
                value=>0.00,
                comment=>"高分子モノマーと溶媒の相互作用の強さ",
            },
            K=>{
                value=>0.00,
                comment=>"二成分溶媒間の相互作用の強さ",
            },
            start=>{
                value=>0.00,
                comment=>,"変化させるパラメータの初期値"
            },
            interval=>{
                value=>0.05,
                comment=>"変化させるパラメータの変化する値",
            },
            end=>{
                value=>0.80,
                comment=>"変化させるパラメータの終わりの値",
            },
    	},
        bool=>{
            nonsol=>{
                value=>FALSE,
                comment=>"溶媒のない条件でシミュレーションを行う.(true->1,false->0)",
            },
            correlation=>{
                value=>FALSE,
                comment=>"系の自己相関,相互相関について計算を行う.(true->1,false->0)",
            },
        },
    	string=>{
            choose_par=>{
                value=>'J',
                comment=>"変化させるパラメータ(J,K,M)",
            },
    	},
	},
);


### usage
sub show_help {
    my $help_doc=<<EOF;
    
Usage:
    perl $0 [options]
    
Options:
    --help       -h     :このスクリプトの詳細を表示
    --read-json  -r		:JSON形式のファイルをパラメータとして入力する
    --dry-run 	 -d     :試しに走らせてみる
    --gen-json 	 -g		:JSON形式の入力用ファイルを作成する
    --dump-yaml  -y     :入力された変数をYAML形式で出力,単体でdefaultのparameterの表示
    --dump-json	 -j		:入力された変数をJSON形式で出力,単体でdefaultのparameterの表示
    
EOF
    return $help_doc;
}
###

### Getopt
GetOptions(
#'--help|?|h'=>\$par{'gethelp'},
	'--help|?|h'=>\&show_help,
	'--read-json|r=s'=>\$par{'read_json'},
	'--dry-run|d'=>\$par{'dryrun'},
	'--dump-yaml|y'=>\$par{'print_yaml'},
	'--dump-json|j'=>\$par{'print_json'},
) or die $!;
###

### Twitter 
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

### Change directory
sub srcwd{
    use Cwd;
    use FindBin;
    
    my $dir=shift||$FindBin::Bin;
    
    $CWD=$dir;
}
###

### Gen-JSON
sub get_json{
    my @hashref=shift;
    
    my $json=JSON::XS->new->pretty(1)->encode(\@hashref);
    
    return $json;
}

sub gen_json{
    
    my $file=shift||$par{'read_json'};
    
    push(my @hashref,shift);
    
    open my $FH, '+>',$file or die $!;
    
    print $FH &get_json(@hashref);
    
    close $FH;
}
###

### Read
sub get_content {
    
    my $file = shift;
    
    my $fh;
    my $content;
    
    if(defined $file){
    	open($fh, '<', $file) or die "Can't open file \"$file\": $!";
        $content = do { local $/; <$fh> };
        close $fh;
    }
    
    return $content;
}

sub json2hash{
    my $file = shift;
    
    my $json=get_content($file);
    my $json_utf8=Encode::encode_utf8($json);
    
    my %hash = %{@{decode_json($json_utf8)}[0]};
    
    return %hash;
}
###

### Dump
sub dump_yaml{
    use YAML::XS;
    
    my %par=shift;
    print STDOUT YAML::XS::Dump %par;
}

sub dump_json{
    my @hashref=shift;
    print STDOUT get_json(@hashref);
}

sub dump_hash{
    my @hashref=shift;
    print STDOUT Dumper(%{$hashref[0]});
}
###

### Assigning machine dependance value to hash
sub hash_assign{
    my @hashref=shift||\%json;
    
    my %hash=%{$hashref[0]};
    
    my $hostname='';
    $hostname=`hostname -s`;
    $hostname=~ s/[\r\n]//g;
    
    $hash{'system'}{'hostname'}{'value'}=$hostname;
    $hash{'system'}{'hostname'}{'comment'}="実行マシンのホスト名";
    
    $hash{'system'}{'perl_stdout'}{'value'}="perl_".$hostname.".txt";
    $hash{'system'}{'perl_stdout'}{'comment'}="このファイルの標準出力ログのファイル名";
    
    $hash{'system'}{'perl_stderr'}{'value'}="perl_".$hostname."_err.txt";
    $hash{'system'}{'perl_stderr'}{'comment'}="このファイルの標準エラー出力ログのファイル名";
    $hash{'system'}{'process'}{'value'}=&count_core;
    $hash{'system'}{'cpuname'}{'value'}=&get_cpu_name;
    
}
###

sub count_core(){
    
    my $core_num;
    my $osname="$^O";
    
    if($osname=~/linux/){
        
        my $core_per_socket=`lscpu|awk '(/ソケットあたりのコア数/){print}'|awk '{sub(":"," ");print \$2}'`;
        
        my $socket=`lscpu|awk '(/Socket/){print \$2}'`;
        
        $core_num=$core_per_socket*$socket;
        
        
    }elsif($osname=~/darwin/){
        
        $core_num=`sysctl machdep.cpu.core_count|awk '{print \$2}'|tr -d '\\n'`;
        
    }else{
        $core_num=-1;
    }
    
    return $core_num;
    
}

sub get_cpu_name(){
    
    my $cpu_name;
    my $osname="$^O";
    
    if($osname=~/linux/){
        $cpu_name=`cat /proc/cpuinfo |grep "model name"|uniq`;
        $cpu_name=~/(?<=:)(.*)/;
        $cpu_name=$1;
        
    }elsif($osname=~/darwin/){
        $cpu_name=`sysctl -n machdep.cpu.brand_string`;
        $cpu_name=~s/\n//g;
    }
    
    return $cpu_name;
    
}

### Generate commandline
sub gen_com{
    
    my @hashref=shift;
    my %hash=%{$hashref[0]};
    
    my $variable=shift;
    my $bottom=shift;
    my $seed=shift;
    my $choose=$hash{'simulation'}{'string'}{'choose_par'}{'value'};
    
    
    
    my $exec=$hash{'environment'}{'executable'};
    my $m=$par{'var'}{'botton_length'};
    my $sn=$par{'var'}{'grafting_point'};
    my $mcs=$par{'var'}{'observe_mcs'};
    my $mz=$par{'var'}{'z_length'};
    my $sl=$par{'var'}{'segment_number'};
    my $J='0.00';
    my $K='0.00';
    
    
    if($choose eq 'J'){
        $J=$variable;
        $K='0.00';
    }elsif($choose eq 'K'){
        $J='0.00';
        $K=$variable;
    }else{
        $J=0.00;
        $K=0.00;
    }
    
    my $command1=sprintf("%s --M %d --SN %d --mcs %d --Mz %d --SL %d --J %f --K %f --seed %d",$exec,$bottom,$sn,$mcs,$mz,$sl,$J,$K,$seed);
    
    my $redirect1=sprintf("1>sol_J%.2fK%.2fM%ds%d.dat",$J,$K,$bottom,$seed);
    my $redirect2=sprintf("2>sol_J%.2fK%.2fM%ds%d_err.dat",$J,$K,$bottom,$seed);
    
    return sprintf("./%s %s %s ",$command1,$redirect1,$redirect2);
}
###


srcwd();

gen_json($par{'read_json'},\%json);

my %hash=json2hash($par{'read_json'});

hash_assign();









