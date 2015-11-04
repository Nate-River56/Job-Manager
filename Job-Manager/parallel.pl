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
use Readonly;
#use Test::More;
#use B::Deparse;
no warnings 'redefine';
###

### Bool value
Readonly my $TRUE =>1;
Readonly my $FALSE=>0;
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
$Data::Dumper::Useperl=$TRUE;
$Data::Dumper::Deparse=$TRUE;
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
            comment=>"Twitter REST API 1.1のconsumer key",
        },
    	consumer_secret =>{
            value=>$ENV{'TWTR_CONS_SEC'},
            comment=>"Twitter REST API 1.1のconsumer secret",
        },
        token=>{
            value=>$ENV{'TWTR_TOKEN_KEY'},
            comment=>"Twitter REST API 1.1のtoken",
        },
        token_secret=>{
            value=>$ENV{'TWTR_TOKEN_SEC'},
            comment=>"Twitter REST API 1.1のtoken secret",
        },
	},
	simulation=>{
    	integer=>{
        	SL=>{
            	array=>[
                	100,
                	200,
                	300,
                ],
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
                array=>[
                	20,
                	30,
                	40,
                ],
                comment=>"xy方向の系の長さ",
            },
            seed=>{
                array=>[
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
                array=>[
                	"0.00",
                	"0.05",
                	"0.10",
                ],
                comment=>"高分子モノマーと溶媒の相互作用の強さ",
            },
            K=>{
                array=>[
                	"0.00",
                	"0.05",
                	"0.10",
                ],
                comment=>"二成分溶媒間の相互作用の強さ",
            },
    	},
        bool=>{
            nonsol=>{
                value=>$FALSE,
                comment=>"溶媒のない条件でシミュレーションを行う.(true->1,false->0)",
            },
            correlation=>{
                value=>$FALSE,
                comment=>"系の自己相関,相互相関について計算を行う.(true->1,false->0)",
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
    --help       -h	:このスクリプトの詳細を表示
    --read       -r	:JSON形式のファイルをパラメータとして入力する
    --dry-run 	 -d	:試しに走らせてみる
    --gen        -g	:JSON形式の入力用ファイルを作成する
    --dump       -p	:各種パラメーターをPerl Hash形式で出力
    --dir        -c	:ディレクトリを設定する
    
EOF
    return $help_doc;
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

### Generate JSON
sub gen_json{
    
    sub get_json{
        my @hashref=shift;
        
        my $json=JSON::XS->new->pretty(1)->encode(\@hashref);
        
        return $json;
    }
    
    my $file=shift;
    
    push(my @hashref,shift);
    
    open my $FH, '+>',$file or die $!;
    
    print $FH &get_json(@hashref);
    
    close $FH;
}
###

### Read
sub json2hash{
    
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
    
    my $file = shift;
    
    my $json=get_content($file);
    my $json_utf8=Encode::encode_utf8($json);
    
    my %hash = %{@{decode_json($json_utf8)}[0]};
    
    return %hash;
}
###

### Dump
sub dump_hash{
    my @hashref=shift||\%json;
    my %hash=%{$hashref[0]};
    print STDOUT Dumper(@hashref);
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

### System environment
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
###

### Generate commandline

sub gen_com{
    
    #my @hashref=shift;
    #my %hash=%{$hashref[0]};
    
    my $J=shift||'0.00';
    my $K=shift||'0.00';
    
    my $bottom=shift;
    my $sl=shift;
    my $seed=shift;
    
    my $exec=$json{'system'}{'program'}{'value'};
    my $m=$json{'var'}{'botton_length'};
    my $sn=$json{'simulation'}{'integer'}{'SN'}{'value'};
    my $mcs=$json{'simulation'}{'integer'}{'mcs'}{'value'};
    my $mz=$json{'simulation'}{'integer'}{'Mz'}{'value'};
    
    my $command1=sprintf("%s --M %d --SN %d --mcs %d --Mz %d --SL %d --J %f --K %f --seed %d",$exec,$bottom,$sn,$mcs,$mz,$sl,$J,$K,$seed);
    
    my $redirect1=sprintf("1>sol_J%.2fK%.2fM%ds%d.dat",$J,$K,$bottom,$seed);
    my $redirect2=sprintf("2>sol_J%.2fK%.2fM%ds%d_err.dat",$J,$K,$bottom,$seed);
    
    return sprintf("./%s %s %s ",$command1,$redirect1,$redirect2);
}

###

### Default Commandline Arguments
my %par=(
"help"		=> $FALSE,
"read"		=> undef,
"dryrun"	=> $FALSE,
"gen"		=> $FALSE,
"dump"		=> $FALSE,
"dir"		=> undef,
);
###

### Getopt

GetOptions(
'--help|?|h'=>\$par{'help'},
'--read|r=s'=>\$par{'read'},
'--dry-run|d'=>\$par{'dryrun'},
'--gen|g'=>\$par{'gen'},
'--dump|p' =>\$par{'dump'},
'--dir|c=s' =>\$par{'dir'},
) or die $!;

sub arg_parse{
    
    if($par{'help'}==$TRUE){
        print &show_help;
        exit(0);
    }
    
    if(defined($par{'dir'})){
        srcwd($par{'dir'});
    }else{
        srcwd();
    }
    
    if(defined($par{'read'})){
        %json=json2hash($par{'read'});
    }
    
    if($par{'gen'}==$TRUE){
        gen_json("sample.json",\%json);
        exit(0);
    }
    
    hash_assign(\%json);
    
    if($par{'dump'}=$TRUE){
        print("\nDump %json\n\n");
        dump_hash(\%json);
        print("\n\nDump %par\n\n");
        dump_hash(\%par);
    }
    
    
}
###

### Twitter
my $twtr;

sub twitter_init{
    
    $twtr = Net::Twitter->new(
    traits => ['API::RESTv1_1'],
    consumer_key => $json{'twitter'}{'consumer_key'}{'value'},
    consumer_secret => $json{'twitter'}{'consumer_secret'}{'value'},
    access_token =>$json{'twitter'}{'token'}{'value'},
    access_token_secret =>$json{'twitter'}{'token_secret'}{'value'},
    SSL => $TRUE,
    );
}

sub tweet{
    my $tweet=shift; # Equal to $_[0]
    my $update=$twtr->update($tweet);
}

sub timeline{
    my $tl=$twtr->home_timeline();
    return $tl;
}
###

sub main{
    
    arg_parse();
    twitter_init();
    
    
}

&main;







