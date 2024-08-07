# Description: Mapping of reads to the centers retrieved by Optics in ashure
# adan@norceresearch.no

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
    config['fasta_path'] = 'ft_dir/*'
    parser.add_argument('-fasta_path', dest='fasta_path', type=str, help='fasta path pattern to map to the centers')
    config['centers']='centers.csv'
    parser.add_argument('-centers', dest='centers', type=str, help='csv file with the centers')
    config['otu_table']='otu_table.csv'
    parser.add_argument('-otu_table', dest='otu_table', type=str, help='otu table with the reads per sample for each center')
    config['fasta_out']='cluster_centers.fasta'
    parser.add_argument('-fasta_out', dest='fasta_out', type=str, help='fasta file with the centers')
    config['sim_thr']=0.8
    parser.add_argument('-sim_thr', dest='sim_thr', type=float, help='simmilarity threshold to allow the aggregation of reads to the centers')
    
    args = parser.parse_args()

    # apply new settings
    config = update_config(config, vars(args))

    # os.chdir('/media/adan/Elements/SLIMtests/testASHURE/testoptics/testmodule')
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
        
        # Group by database_id and sum the size values
        size_sum = B_merged.groupby('database_id')['size'].sum().reset_index()
        
        # Assign the summed size values to the clst DataFrame
        clst = clst.merge(size_sum, left_on='id', right_on='database_id', how='left')
        clst[sample_name] = clst['size']
        clst.drop(columns=['database_id', 'size'], inplace=True)

        # if there is any NaN value, fill it with 0
        clst.fillna(0, inplace=True)
    
    clst.to_csv(config['otu_table'], index=False)
    bpy.write_fasta(config['fasta_out'], clst[['id', 'sequence']])

if __name__ == "__main__":
    main()
    print('Done!')