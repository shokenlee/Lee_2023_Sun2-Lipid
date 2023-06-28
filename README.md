# Lee et al. 2023 J Cell Biol.

Custom scripts for image analysis performed in Lee et al. 2023 J Cell Biol (doi: 10.1083/jcb.202304026).

Written in ImageJ Macro and Python (Jupyter Notebook).

Two sets of codes for measuring:
- NE enrichment score
- Protein abundance in nucleus area (e.g. Sun2)

## NE enrichment score

Performed in **Figure 1**. Image anaylysis was performed by ImageJ Macro (NE_enrich_score.ijm) as depicted below:

![Image](/assets/Scheme_NE_en_score.png)

Then, the resulting spreadsheets were concatenated and further analyzed using the Python code (NE_enrich_score.ipynb).

## Protein abundacne in nucleus area (e.g. Sun2)

Performed in **Figures 2 and S2**. Staining intensity of the protein of interest within nucleus area was measured by ImageJ Macro (Nuclear_abundance.ijm). Nucleus are was defined using StarDist plugin. Then, the resulting spreadsheets were concatenated and further analyzed using the Python code (Nuclear_abundance.ipynb).

![Image](/assets/Scheme_Nuclear_abundance.png)
