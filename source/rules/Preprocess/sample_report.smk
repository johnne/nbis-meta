localrules:
    samples_qc_report

rule fastqc:
    """Run fastqc on preprocessed data"""
    input:
        opj(config["intermediate_path"],"preprocess",
            "{sample}_{run}_{pair}"+PREPROCESS+".fastq.gz")
    output:
        opj(config["intermediate_path"],"fastqc",
            "{sample}_{run}_{pair}"+PREPROCESS+"_fastqc.zip")
    params:
        results_path=opj(config["intermediate_path"],"fastqc")
    shadow: "shallow"
    resources:
        runtime = lambda wildcards, attempt: attempt**2*60
    conda:
        "../../../envs/preprocess.yml"
    shell:
        "fastqc -q --noextract -o {params.results_path} {input}"

def get_fastqc_files(wildcards):
    """Get all fastqc output"""
    files = []
    for sample in samples.keys():
        for run in samples[sample].keys():
            for pair in samples[sample][run].keys():
                if pair in ["R1","R2","se"]:
                    if config["preprocess"]:
                        files.append(opj(config["intermediate_path"],
                            "fastqc","{}_{}_{}{}_fastqc.zip".format(sample,
                            run,pair,PREPROCESS)))
                    else:
                        files.append(opj(config["intermediate_path"],
                            "fastqc","{}_{}_{}_fastqc.zip".format(sample,
                            run,pair)))
    return files

def get_trim_logs(wildcards):
    """
    Get all trimming logs from Trimmomatic and/or cutadapt

    :param wildcards: wildcards from snakemake
    :return: list of files
    """
    files = []
    if not config["trimmomatic"] and not config["cutadapt"]:
        return files
    if config["trimmomatic"]:
        trimmer = "trimmomatic"
    elif config["cutadapt"]:
        trimmer = "cutadapt"
    for sample in samples.keys():
        for run in samples[sample].keys():
            for pair in samples[sample][run].keys():
                if pair in ["R1","R2","se"]:
                    logfile = opj(config["intermediate_path"],"preprocess",
                                  "{}_{}_{}{}.{}.log".format(sample,
                        run,pair,preprocess_suffices["trimming"],trimmer))
                    files.append(logfile)
    return files

def get_filt_logs(wildcards):
    """
    Get all filter logs from Phix filtering

    :param wildcards: wildcards from snakemake
    :return: list of files
    """
    files = []
    if not config["phix_filter"]: return files
    for sample in samples.keys():
        for run in samples[sample].keys():
            if "R2" in samples[sample][run].keys():
                logfile = opj(config["intermediate_path"],"preprocess",
                    "{}_{}_PHIX_pe{}.log".format(sample,run,
                                            preprocess_suffices["phixfilt"]))
            else:
                logfile = opj(config["intermediate_path"],"preprocess",
                    "{}_{}_PHIX_se{}.log".format(sample,run,
                                            preprocess_suffices["phixfilt"]))
            files.append(logfile)
    return files

def get_sortmerna_logs(wildcards):
    """
    Get all logs from SortMeRNA

    :param wildcards: wildcards from snakemake
    :return: list of files
    """
    files = []
    if not config["sortmerna"]:
        return files
    for sample in samples.keys():
        for run in samples[sample].keys():
            if "R2" in samples[sample][run].keys():
                logfile = opj(config["intermediate_path"],"preprocess",
                              "{}_{}_pe.sortmerna.log".format(sample,run))
            else:
                logfile = opj(config["intermediate_path"],"preprocess",
                              "{}_{}_se.sortmerna.log".format(sample,run))
            files.append(logfile)
    return files

rule aggregate_logs:
    """Rule for aggregating preprocessing logs"""
    input:
        trimlogs=get_trim_logs,
        sortmernalogs=get_sortmerna_logs,
        filtlogs=get_filt_logs,
        fastqc=get_fastqc_files
    output:
        touch(opj(config["report_path"],"multiqc_input","flag"))
    params:
        output_dir=opj(config["report_path"],"multiqc_input")
    run:
        for file in input.trimlogs:
            shell("cp {file} {params.output_dir}")
        for file in input.sortmernalogs:
            shell("cp {file} {params.output_dir}")
        for file in input.filtlogs:
            shell("cp {file} {params.output_dir}")
        for file in input.fastqc:
            shell("cp {file} {params.output_dir}")

rule samples_qc_report:
    """Summarize sample QC statistics in a report """
    input:
        opj(config["report_path"],"multiqc_input","flag")
    output:
        opj(config["report_path"],"samples_report.html"),
        opj(config["report_path"],"samples_report_data",
            "multiqc_general_stats.txt")
    shadow:
        "shallow"
    params:
        config="config/multiqc_preprocess_config.yaml",
        output_dir=opj(config["report_path"]),
        input_dir=opj(config["report_path"],"multiqc_input")
    conda:
        "../../../envs/preprocess.yml"
    shell:
        """
        multiqc \
            -f \
            -c {params.config} \
            -n samples_report.html \
            -o {params.output_dir} \
            $(dirname {input})
        rm -r {params.input_dir}
        """