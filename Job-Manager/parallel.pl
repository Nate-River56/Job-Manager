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
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat bundling);
use Net::Twitter;
use JSON::XS;
use Encode;
use FindBin;
use File::Tee qw(tee);
use IO::File;
use Acme::Comment type=>'C++', own_line => $FALSE, one_line => $TRUE;
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
	'system'=>{
        'program'=>{
            'value'=>'../bin/sol.s.out',
            'comment'=>"プログラムのファイル名",
        },
        'twitter_use'=>{
            'value'=>$FALSE,
            'comment'=>'まだ追加したのみで実際には機能しないパラメータ',
        },
        'sqlite_db'=>{
            'value'=>"../sol.sqlite",
            'comment'=>'SQLiteのデータベースの作成するor存在するPATH(すべてのnodeで共通にする)',
        },
	},
	'twitter'=>{
        'consumer_key'=>{
            'value'=>$ENV{'TWTR_CONS_KEY'},
            'comment'=>"Twitter REST API 1.1のconsumer key",
        },
    	'consumer_secret' =>{
            'value'=>$ENV{'TWTR_CONS_SEC'},
            'comment'=>"Twitter REST API 1.1のconsumer secret",
        },
        'token'=>{
            'value'=>$ENV{'TWTR_TOKEN_KEY'},
            'comment'=>"Twitter REST API 1.1のtoken",
        },
        'token_secret'=>{
            'value'=>$ENV{'TWTR_TOKEN_SEC'},
            'comment'=>"Twitter REST API 1.1のtoken secret",
        },
	},
	'simulation'=>{
    	'integer'=>{
        	'SL'=>{
            	'array'=>[
                	100,
                	200,
                	300,
                ],
            	'comment'=>"高分子のセグメント数",
            },
            'SN'=>{
            	'value'=>50,
                'comment'=>"高分子鎖の植え付け本数",
            },
            'M'=>{
                'array'=>[
                	20,
                	30,
                	40,
                ],
                'comment'=>"xy方向の系の長さ",
            },
            'Mz-L'=>{
                'value'=>30,
                'comment'=>"Z方向の系の長さ-高分子の長さ(空間的余裕分)",
            },
            'seed'=>{
                'array'=>[
                	1,
                	2,
                	3,
                ],
                'comment'=>"乱数のseed",
            },
            'mcs'=>{
                'value'=>10000000,
                'comment'=>"Monte-Carlo-Step数",
            },
    	    
    	},
    	'float'=>{
            'J'=>{
                'array'=>[
                	"0.00",
                	"0.05",
                	"0.10",
                ],
                'comment'=>"高分子モノマーと溶媒の相互作用の強さ",
            },
            'K'=>{
                'array'=>[
                	"0.00",
                	"0.05",
                	"0.10",
                ],
                'comment'=>"二成分溶媒間の相互作用の強さ",
            },
    	},
        'bool'=>{
            'correlation'=>{
                'value'=>"false",
                'comment'=>"系の自己相関,相互相関について計算を行う.(\"true\" or \"false\")",
            },
        },
	},
);

### usage
sub show_help {
    
    my $defhashref=shift;
    my %defhash=%$defhashref;
    
    my $help_doc=<<EOF;
    
Usage:
    perl $0 [options]
    
Options(Not Required):
    
    <ex. --long-option -short-option :Caption [Argument type(Default-value)]  >
	
    --help       -h    : このスクリプトの詳細を表示                             [Nil]
    --read       -r    : JSON形式のファイルをパラメータとして入力する           [String]
    --dry-run    -d    : 試しに走らせてみる                                     [Nil]
    --gen        -g    : JSON形式の入力用ファイルを作成する                     [String(\"$defhash{'gen'}\")]
    --dump       -p    : パラメータをPerl Hash形式で出力する                    [String(\"$defhash{'dump'}\")]
    --dump-json  -j    : パラメータをJSON形式で出力する                         [String(\"$defhash{'dump-json'}\")]
    --dir        -c    : ディレクトリを設定する                                 [String(\"$FindBin::Bin\")]
    --clean      -e    : デフォルトのファイルを削除する                         [Nil]
    --no-twitter -n    : Twitter機能を使用しない                                [Nil]
    --log        -l    : Printing log ,but stdio/stderr does not suppressed.    [Nil]
    --license    -L    : ライセンスを表示する, Printing License of this code.   [Nil]
    
Reading Environment Value:
    Option "--gen,-g"で入力用JSONファイルを生成するときに、以下の環境変数を参照します。
    これらの値はファイルに直接書き入れるのであれば設定不要です。
    
    'TWTR_CONS_KEY','TWTR_CONS_SEC','TWTR_TOKEN_KEY','TWTR_TOKEN_SEC'
    
EOF
    return $help_doc;
}
###

sub license{
    
    my $license_doc=<<EOF;

 Copyright 2015 Nate-River56

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0
    
EOF
    return $license_doc;
}

### Change directory
sub setwd{
    use Cwd;
    
    my $dir=shift;
    
    $CWD=$dir;
}
###

### Generate JSON
sub gen_json{
    
    sub get_json{
        my $hashref=shift;
        
        my $json=JSON::XS->new->pretty(1)->encode($hashref);
        
        return $json;
    }
    
    my $file=shift;
    my $hashref=shift;
    
    open my $FH, '+>',$file or die $!;
    
    print $FH &get_json($hashref);
    
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
    
    my %hash = %{decode_json($json_utf8)};
    
    return %hash;
}
###

### Dump
sub dump_hash{
    my $hashref=shift || \%json;
    my %hash=%$hashref;
    return(Dumper($hashref));
}
###

### Assigning machine dependance value to hash
sub hash_assign{
    my $hashref=shift;
    
    my %hash=%$hashref;
    
    my $hostname=`hostname -s`;
    $hostname=~ s/[\r\n]//g;
    
    $hash{'system'}{'hostname'}{'value'}=$hostname;
    $hash{'system'}{'hostname'}{'comment'}="実行マシンのホスト名";
    
    $hash{'system'}{'perl_stdout'}{'value'}="perl_".$hostname.".txt";
    $hash{'system'}{'perl_stdout'}{'comment'}="このファイルの標準出力ログのファイル名";
    
    $hash{'system'}{'perl_stderr'}{'value'}="perl_".$hostname.".err.txt";
    $hash{'system'}{'perl_stderr'}{'comment'}="このファイルの標準エラー出力ログのファイル名";
    
    $hash{'system'}{'process'}{'value'}=&count_core+0;
    $hash{'system'}{'process'}{'comment'}="実行する時のフォークするプロセスの最大数";
    
    $hash{'system'}{'cpuname'}{'value'}=&get_cpu_name;
    $hash{'system'}{'cpuname'}{'comment'}="実行しているマシンに搭載されているCPU型番";
    
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
        $core_num=undef;
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

### Getopt
my $opt_dry_run=$FALSE;
my $opt_no_twitter=$FALSE;
sub arg_parse{
    
    ### Default option
    my %default=(
    'gen'=>"sample.json",
    'dump'=>"hash.txt",
    'dump-json'=>"trace.json",
    'dir'=>$FindBin::Bin,
    );
    ###
	
	my $hashref=shift;
	my %par=%$hashref;
	
	setwd($FindBin::Bin);
	
    #$_[0] means long_name. $_[1] means argument.
	GetOptions(
	'--help|?|h'		=> sub{print STDERR &show_help(\%default);exit(0)},
	'--read|r=s'		=> sub{%par=json2hash($_[1])},
	'--dry-run|d'		=> \$opt_dry_run,
    '--gen|g:s'			=> sub{gen_json($_[1] || $default{$_[0]},\%par);exit(0)},
	'--dump|p:s'		=> sub{hash_assign(\%par);print &dump_hash(\%par)},
    '--dir|c:s'			=> sub{setwd($_[1] || $default{$_[0]})},
    '--dump-json|j:s'	=> sub{hash_assign(\%par);gen_json($_[1] || $default{$_[0]},\%par)},
    '--clean|e'         => sub{&clean(\%default);exit(0)},
    '--log|l'           => sub{hash_assign(\%par);&handle_tee(\%par)},
    '--no-twitter|n'    => \$opt_no_twitter,
    '--license|L'         => sub{print STDERR &license;exit(0);},
	) or die $!;
	
    
    return %par;
}
###

### Twitter
my $twtr=undef;

sub twitter_init{
    
    
    if($opt_dry_run==$FALSE or $opt_no_twitter==$FALSE){
        print(STDERR "Negotiating Twitter API Server\n");
        $twtr = Net::Twitter->new(
            traits => ['API::RESTv1_1'],
            consumer_key => $json{'twitter'}{'consumer_key'}{'value'},
            consumer_secret => $json{'twitter'}{'consumer_secret'}{'value'},
            access_token =>$json{'twitter'}{'token'}{'value'},
            access_token_secret =>$json{'twitter'}{'token_secret'}{'value'},
            SSL => $TRUE,
        ) or die $!;
        return($TRUE)
        
    }else{
        $twtr=undef;
        print(STDERR "Do not negotiate Twitter API Server.");
        return($FALSE)
    }
    
}

sub tweet{
    my $tweet=shift; # Equal to $_[0]
    if(defined $twtr and $opt_no_twitter==$FALSE and $opt_dry_run==$FALSE){
        my $update=$twtr->update($tweet) or die $!."\n";
        print(STDOUT "Tweet: ".$tweet)
    }else{
        print(STDOUT "Twitter Disabled.\n");
        print(STDOUT "Print: ".$tweet."\n");
    }
}

sub timeline{
    if(defined $twtr){
        my $tl=$twtr->home_timeline();
        return $tl;
    }
}
###

sub handle_tee{
    my $hashref=shift;
    my %hash=%$hashref;
    
    tee('STDOUT','>',$hash{'system'}{'perl_stdout'}{'value'}) or die $!;
    tee('STDERR','>',$hash{'system'}{'perl_stderr'}{'value'}) or die $!;
}

sub clean{
    
    my $defhashref=shift;
    my %defhash=%$defhashref;
    
    my $hostname=`hostname -s`;
    $hostname=~ s/[\r\n]//g;
    my $stdname="perl_".$hostname.".txt";
    my $errname="perl_".$hostname.".err.txt";
    
    
    my @del=($defhash{'gen'},$defhash{'dump'},$defhash{'dump-json'},
             $stdname,$errname);
    
    foreach my $file (@del){
        unlink $file or warn "Cannot delete $file  : $!\n";
    }
    
}

### Generate commandline
sub gen_com{ #(J,K,bottom,sl,seed)
    
    my $hashref=shift;
    my %par=%$hashref;
    
    my $J=shift || '0.00';
    my $K=shift || '0.00';
    
    my $bottom=shift;
    my $sl=shift;
    my $seed=shift;
    
    my $exec=$par{'system'}{'program'}{'value'};
    my $m=$par{'var'}{'botton_length'};
    my $sn=$par{'simulation'}{'integer'}{'SN'}{'value'};
    my $mcs=$par{'simulation'}{'integer'}{'mcs'}{'value'};
    my $mz=$par{'simulation'}{'integer'}{'Mz-L'}{'value'}+$sl;
    my $db=$par{'system'}{'sqlite_db'}{'value'};
    
    my $nonsol=" ";
    my $correlation=" ";
    my $command1="";
    
    if($par{'bool'}{'correlation'}{'value'} eq "true"){
        $correlation="--correlation";
    }else{
        $correlation=" ";
    }
    
    if($J==0 and $K==0){
       $command1=sprintf("%s --M %d --SN %d --mcs %d --Mz %d --SL %d --nonsol --seed %d --db %s %s",$exec,$bottom,$sn,$mcs,$mz,$sl,$seed,$db,$correlation);
        $J='0.00';
        $K='0.00';
    }else{
       $command1=sprintf("%s --M %d --SN %d --mcs %d --Mz %d --SL %d --J %s --K %s --seed %d --db %s %s",$exec,$bottom,$sn,$mcs,$mz,$sl,$J,$K,$seed,$db,$correlation);
    }
    
    
    my $redirect1=sprintf("1>sol_J%sK%sM%dL%ss%d.dat",$J,$K,$bottom,$sl,$seed);
    my $redirect2=sprintf("2>sol_J%sK%sM%dL%ss%d_err.dat",$J,$K,$bottom,$sl,$seed);
    
    return sprintf("./%s %s %s ",$command1,$redirect1,$redirect2);
}
###
sub task{
    
    use Parallel::ForkManager;
    
    my $hashref=shift;
    my %par=%$hashref;
    
    my $hostname="";
    $hostname=$par{'system'}{'hostname'}{'value'};
    
    my $pm = new Parallel::ForkManager($par{'system'}{'process'}{'value'});
    
    $pm->run_on_start(
        sub{
            
            my $date=localtime."";
            
            my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data)=@_;
            my $tw="** At $hostname , started, pid: $pid, $date\n";
            tweet($tw);
        }
    );
    
    $pm->run_on_finish(
        sub {

            my $date=localtime."";
            
            my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data) = @_;
            my $tw="** At $hostname, just got out ".
            "with PID $pid and exit code: $exit_code, $date\n\n";
            tweet($tw);
        }
    );
    
    $pm->run_on_wait(
        sub{
        
            my $date=localtime."";
        
        
            print STDOUT "waitin.\n";
        
        }
    );
    
    
    foreach   my $M  (@{$par{'simulation'}{'integer'}{'M'}{'array'}})    {
        foreach   my $SL  (@{$par{'simulation'}{'integer'}{'SL'}{'array'}})  {
            foreach   my $seed  (@{$par{'simulation'}{'integer'}{'seed'}{'array'}}) {
                foreach   my $J  (@{$par{'simulation'}{'float'}{'J'}{'array'}})         {
                    foreach   my $K  (@{$par{'simulation'}{'float'}{'K'}{'array'}})         {
                        
                        
                        if (my $pid=$pm->start) {
                            Time::HiRes::sleep(0.5);
                            next;
                        }
                        
                        my $line=gen_com(\%par,$J,$K,$M,$SL,$seed)||"";
                        
                        print(STDOUT "Execute: ".$line."\n");
                        if($opt_dry_run==$FALSE){
                            system($line);
                        }
                        
                        
                        tweet("Finished Job at $hostname, ".localtime);
                        
                        Time::HiRes::sleep(0.5);
                        
                        $pm->finish;
                        
                    }
                }
            }
        }
    }
    
    print(STDOUT "Waiting Children.\n");
    $pm->wait_all_children;
    
    print(STDOUT "All end at $hostname.\n");
    
}
###


sub main{
    
    
    my %par=arg_parse(\%json);
    
    {
        my $hostname=`hostname -s`;
        $hostname=~ s/[\r\n]//g;
        
        $par{'system'}{'hostname'}{'value'}=$hostname;
        $par{'system'}{'hostname'}{'comment'}="実行マシンのホスト名";
        
        $par{'system'}{'perl_stdout'}{'value'}="perl_".$hostname.".txt";
        $par{'system'}{'perl_stdout'}{'comment'}="このファイルの標準出力ログのファイル名";
        
        $par{'system'}{'perl_stderr'}{'value'}="perl_".$hostname.".err.txt";
        $par{'system'}{'perl_stderr'}{'comment'}="このファイルの標準エラー出力ログのファイル名";
        
        $par{'system'}{'process'}{'value'}=&count_core+0;
        $par{'system'}{'process'}{'comment'}="実行する時のフォークするプロセスの最大数";
        
        $par{'system'}{'cpuname'}{'value'}=&get_cpu_name;
        $par{'system'}{'cpuname'}{'comment'}="実行しているマシンに搭載されているCPU型番";
        
    }
    
    
    
    my $twtr_avail=twitter_init();
    
    
    &task(\%par);
    
    exit(0);
}

&main;







