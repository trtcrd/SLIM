# Description: Mapping of reads to the centers retrieved by Optics in ashure
# adan@norceresearch.no
# This script was originally made by Pascal. He may have a better perspective on how to use it.
# pascal.hablutzel@vliz.be

# load libraries
import argparse
import pandas as pd
import sys
import os
import glob


# Define the new path to load bilge_pype
bpypath = os.path.abspath('/app/lib/ASHURE/src/')
# Add the new path to sys.path
if bpypath not in sys.path:
    sys.path.append(bpypath)

# Now you can import bilge_pype
import bilge_pype as bpy



def update_config(default, new_config):
    '''
    Updates default variables with user specified variables
    default = dict contain default variables
    new_config = dict contain new variables
    '''
    # update settings
    for k in new_config.keys():
        if new_config[k]!=None:
            default[k] = new_config[k]
    return default

def main():
    # read arguments
    parser = argparse.ArgumentParser(description='after Optics: Mapping of reads to the centers retrieved by Optics in ashure',
                        formatter_class=argparse.RawTextHelpFormatter)
    # variable to store default configs
    config = {}
    # define paths to the aligner tools
    config['dir'] = []
    parser.add_argument('-dir', dest='dir', type=str, help='working directory')
    config['fasta_path'] = 'fasta_dir_tmp/*'
    parser.add_argument('-fasta_path', dest='fasta_path', type=str, help='fasta path pattern to map to the centers')
    config['centers']='centers.csv'
    parser.add_argument('-centers', dest='centers', type=str, help='csv file with the centers')
    config['otu_table']='otu_table.tsv'
    parser.add_argument('-otu_table', dest='otu_table', type=str, help='otu table with the reads per sample for each center')
    config['fasta_out']='cluster_centers.fasta'
    parser.add_argument('-fasta_out', dest='fasta_out', type=str, help='fasta file with the centers')
    config['sim_thr']=0.8
    parser.add_argument('-sim_thr', dest='sim_thr', type=float, help='simmilarity threshold to allow the aggregation of reads to the centers')
    config['merged_out']='merged_out.tsv'
    parser.add_argument('-merged_out', dest='merged_out', type=float, help='output file with the information of the reads mapped to the centers')
    
    args = parser.parse_args()

    # apply new settings
    config = update_config(config, vars(args))

    os.chdir(config['dir'])
    bpy._minimap2 = '/app/lib/msi/bin/minimap2'

    # get the names of the files
    # get the names of files matching the pattern
    inputs = glob.glob(config['fasta_path'])

    clst = pd.read_csv(config['centers'])
    db = clst
    db['source'] = 'clst'
    cols = ['id','sequence','source']
    db = db[cols]
    clst = clst[['id','sequence']]
    # create a void dataframe to store the merging information
    merged_info = pd.DataFrame(columns=['index', 'id', 'q_len', 'q_start', 'q_end', 'orientation',
                                        'database_id', 't_len', 't_start', 't_end', 'match', 'tot', 'mapq',
                                        'tp', 'cm', 's1', 's2', 'NM', 'AS', 'ms', 'nn', 'rl', 'CIGAR',
                                        'match_score', 'similarity', 'size'])
    for input in inputs:
        infas = bpy.load_file(input)
        infas['source'] = 'samples'
        sample_name = os.path.splitext(os.path.basename(input))[0]
        if infas['id'].str.contains('size=').all():
            infas[['id', 'size']] = infas['id'].str.split(';.*size=', expand=True)
            infas['size'] = infas['size'].str.replace(';', '').astype(int)
        else:
            infas['size'] = 1
        B = bpy.run_minimap2(infas, db, config='-k8 -w1', cleanup=False).rename(columns={'query_id':'id'})
        B = bpy.get_best(B,['id'],metric='AS',stat='idxmax')
        # Filter B for similarity higher than sim_thr
        B_filtered = B[B['similarity'] > config['sim_thr']]
        # Merge B_filtered with infas to get the size values
        B_merged = B_filtered.merge(infas[['id', 'size']], on='id', how='left')
        # join the merged_info with B_merged
        merged_info = pd.concat([merged_info, B_merged])
        # Group by database_id and sum the size values
        size_sum = B_merged.groupby('database_id')['size'].sum().reset_index()
        # Assign the summed size values to the clst DataFrame
        clst = clst.merge(size_sum, left_on='id', right_on='database_id', how='left')
        clst[sample_name] = clst['size']
        clst.drop(columns=['database_id', 'size'], inplace=True)
        # if there is any NaN value, fill it with 0
        clst.fillna(0, inplace=True)
        
    # change if the OTU_ID is a string with the word 'clsuter' change it to 'OTU'
    clst['id'] = clst['id'].str.replace('cluster', 'OTU')
    bpy.write_fasta(config['fasta_out'], clst[['id', 'sequence']])
    # change the colname 'id' to 'OTU_ID'
    clst.rename(columns={'id':'OTU_ID'}, inplace=True)
    # remove the sequence column
    clst.drop(columns='sequence', inplace=True)
    # Round all columns except for 'OTU_ID' to 0 decimal places and convert to int
    clst.iloc[:, 1:] = clst.iloc[:, 1:].round(0).astype(int)
    clst.to_csv(config['otu_table'], sep='\t', index=False)

    merged_info['database_id'] = merged_info['database_id'].str.replace('cluster', 'OTU')
    merged_info.to_csv(config['merged_out'], sep='\t', index=False)

if __name__ == "__main__":
    main()
    print('Done!')