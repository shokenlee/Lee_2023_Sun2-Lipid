

column_dict_lib = {
    'Cell_type': {'ctrl': 'Ctrl', 'KO': 'CTDNEP1 KO'}, 
    'siRNA': {'siCtrl': 'siCtrl', 'CTDNEP1': 'siCTDNEP1', 'Lpin1': 'siLpin1', 'NEP1R1': 'siNEP1R1'},
    'Drug': {'DMSO': 'DMSO', 'pra': 'Propranolol'},
    'Plasmid': {'WT': 'WT', 'HA': 'H426A'}
}

def insert_columns(df, **kwargs):
    for column_name, column_values in kwargs.items():
        for k, v in column_values.items():
            df.loc[df['FileName'].str.contains(k), column_name] = v