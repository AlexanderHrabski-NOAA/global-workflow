=============
Configure Run
=============

The GW configs contain switches that change how the system runs. Many defaults are set initially. Users wishing to run with different settings should adjust their $EXPDIR configs and then rerun the ``setup_workflow.py`` script since some configuration settings/switches change the workflow/xml ("Adjusts XML" column value is "YES").

+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| Switch           | What                             | Default       | Adjusts XML | More Details                                      |
+==================+==================================+===============+=============+===================================================+
| APP              | Model application                | ATM           | YES         | See case block in config.base for options         |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| DEBUG_POSTSCRIPT | Debug option for PBS scheduler   | NO            | YES         | Sets debug=true for additional logging            |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| DOIAU            | Enable 4DIAU for control         | YES           | NO          | Turned off for cold-start first half cycle        |
|                  | with 3 increments                |               |             |                                                   |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| DOHYBVAR         | Run EnKF                         | YES           | YES         | Don't recommend turning off                       |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| DONST            | Run NSST                         | YES           | NO          | If YES, turns on NSST in anal/fcst steps, and     |
|                  |                                  |               |             | turn off rtgsst                                   |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| DO_AWIPS         | Run jobs to produce AWIPS        | NO            | YES         | downstream processing, ops only                   |
|                  | products                         |               |             |                                                   |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| DO_BUFRSND       | Run job to produce BUFR          | NO            | YES         | downstream processing                             |
|                  | sounding products                |               |             |                                                   |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| DO_GEMPAK        | Run job to produce GEMPAK        | NO            | YES         | downstream processing, ops only                   |
|                  | products                         |               |             |                                                   |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| DO_FIT2OBS       | Run FIT2OBS job                  | YES           | YES         | Whether to run the FIT2OBS job                    |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| DO_TRACKER       | Run tracker job                  | YES           | YES         | Whether to run the tracker job                    |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| DO_GENESIS       | Run genesis job                  | YES           | YES         | Whether to run the genesis job                    |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| DO_GENESIS_FSU   | Run FSU genesis job              | YES           | YES         | Whether to run the FSU genesis job                |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| DO_VERFOZN       | Run GSI monitor ozone job        | YES           | YES         | Whether to run the GSI monitor ozone job          |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| DO_VERFRAD       | Run GSI monitor radiance job     | YES           | YES         | Whether to run the GSI monitor radiance job       |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| DO_VMINMON       | Run GSI monitor minimization job | YES           | YES         | Whether to run the GSI monitor minimization job   |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| DO_ANLSTAT       | Run analysis statistics job      | NO            | YES         | Whether to run the analysis statistics job.       |
|                  |                                  |               |             | Automatically set to YES for JEDI-based           |
|                  |                                  |               |             | experiments (DO_JEDIATMVAR, DO_AERO,              |
|                  |                                  |               |             | DO_JEDIOCNVAR, or DO_JEDISNOWDA).                 |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| DO_GSI_ANLSTAT   | Run GSI analysis statistics job  | NO            | NO          | Whether to include GSI-based atmospheric analysis |
|                  |                                  |               |             | statistics when running the anlstat job. Only     |
|                  |                                  |               |             | relevant when DO_ANLSTAT=YES and using GSI (not   |
|                  |                                  |               |             | JEDI) for atmospheric data assimilation.          |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| DO_METP          | Run METplus jobs                 | YES           | YES         | One cycle spinup                                  |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| EXP_WARM_START   | Is experiment starting warm      | .false.       | NO          | Impacts IAU settings for initial cycle. Can also  |
|                  | (.true.) or cold (.false)?       |               |             | be set when running ``setup_expt.py`` script with |
|                  |                                  |               |             | the ``--start`` flag (e.g. ``--start warm``)      |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| DO_ARCHCOM       | Archive COM                      | YES/NO        | YES         | Whether to archive the COM structure.  Defaults   |
|                  |                                  |               |             | are machine-specific.                             |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| ARCHCOM_TO       | Where to archive COM             | hpss, local,  | YES         | If DO_ARCHCOM is YES, then this variable indicates|
|                  |                                  | or globus_hpss|             | where the COM structure tarballs should be saved. |
|                  |                                  |               |             | Choices are 'hpss', 'local', or 'globus_hpss'.    |
|                  |                                  |               |             | HPSS archiving requires a direct connection.      |
|                  |                                  |               |             | Globus-HPSS archiving uses Mercury as a server to |
|                  |                                  |               |             | archiving to HPSS.  This is currently only        |
|                  |                                  |               |             | supported on Hercules.  Defaults are machine      |
|                  |                                  |               |             | specific.                                         |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| ARCH_EXPDIR      | Archive the EXPDIR               | NO            | NO          | Whether to create a tarball of the EXPDIR.        |
|                  |                                  |               |             | ARCH_HASHES and ARCH_DIFFS generate text files    |
|                  |                                  |               |             | of git output that are archived with the EXPDIR.  |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| QUILTING         | Use I/O quilting                 | .true.        | NO          | If .true. choose OUTPUT_GRID as cubed_sphere_grid |
|                  |                                  |               |             | in netcdf or gaussian_grid                        |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| CAT_MPMD_LOGS    | Write MPMD logs back to the      | YES           | NO          | If YES, the contents of the MPMD logs will be     |
|                  | parent log.                      |               |             | written to the parent log file.                   |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| WRITE_DOPOST     | Run inline post                  | .true.        | NO          | If .true. produces master post output in forecast |
|                  |                                  |               |             | job                                               |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+
| USE_BUILD_GSINFO | Build the GSI info files         | YES           | NO          | If YES, the GSI analysis jobs will build the      |
|                  |                                  |               |             | satinfo, cnvinfo, and ozinfo files dynamically.   |
|                  |                                  |               |             | If NO, static versions located in the GSI FIX     |
|                  |                                  |               |             | directory will be used.                           |
+------------------+----------------------------------+---------------+-------------+---------------------------------------------------+

^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Custom MOM6 and CICE6 input template paths
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``link_workflow.sh`` stages the MOM6 and CICE6 input templates from
``sorc/ufs_model.fd/tests/parm`` into ``${PARMglobal}/ufs``. Those staged copies
are the only ones an experiment can use, they are listed in ``.gitignore``, and
``link_workflow.sh`` deletes and recreates them on every run. Tracking a modified
``MOM_input`` alongside an experiment therefore meant forking ufs-weather-model
for a single text file.

These variables let an experiment take those templates from its own directory
instead. Each defaults to the staged copy, so an experiment that sets none of
them behaves exactly as before.

``MOM6_TEMPLATE_DIR`` (``config.ocn``)
  Directory holding both MOM6 templates. Defaults to ``${PARMglobal}/ufs``. A
  directory set here must contain *every* MOM6 template -- there is no per-file
  fallback to ``${PARMglobal}/ufs``, and a missing file aborts the forecast job.
  To replace only one template, use its own variable instead.

``MOM6_INPUT_TEMPLATE`` (``config.ocn``)
  Full path to the ``MOM_input`` template. Defaults to
  ``${MOM6_TEMPLATE_DIR}/MOM_input_${OCNRES}.IN``. Note the resolution suffix in
  that default: a per-file override is the only way to use a template whose name
  does not follow the ``MOM_input_<res>.IN`` pattern.

``MOM6_DATA_TABLE_TEMPLATE`` (``config.ocn``)
  Full path to the ``data_table`` template. Defaults to
  ``${MOM6_TEMPLATE_DIR}/MOM6_data_table.IN``.

``CICE_TEMPLATE`` (``config.ice``)
  Full path to the ``ice_in`` template. Defaults to
  ``${PARMglobal}/ufs/ice_in.IN``. ``ice_in`` is the only CICE6 template, so
  there is no directory variable to go with it.

Set them in the YAML passed to ``setup_expt.py --yaml``, under the section named
for the config that owns each one. That YAML must include the stock defaults with
``!INC`` -- the sections beside ``defaults`` override it, they do not add to it,
so a file without the include would drop every other setting::

  defaults:
    !INC {{ HOMEglobal }}/dev/parm/config/gfs/yaml/defaults.yaml
  ocn:
    MOM6_INPUT_TEMPLATE: /path/to/my_experiment/configs/MOM_input_008.IN
  ice:
    CICE_TEMPLATE: /path/to/my_experiment/configs/ice_in.IN

See ``dev/ci/cases/yamls/gfs_defaults_ci.yaml`` for a working example of that
layout.

Because the paths live in the experiment YAML rather than in an edited ``$EXPDIR``
config, they survive re-running ``setup_expt.py`` and can be version controlled
alongside the templates they point at.

Keep the atparse tokens
"""""""""""""""""""""""

These files are templates, not finished namelists. They are rendered with
``atparse``, which substitutes every ``@[VARIABLE]`` token from the shell
environment. The stock templates carry 28 distinct tokens in
``MOM_input_025.IN``, 55 in ``ice_in.IN`` and one in ``MOM6_data_table.IN``.

Start from a copy of the stock template and keep its tokens. They are how the
workflow injects per-cycle and per-job settings, and a token deleted from a
custom template fails silently: the model simply falls back to its own compiled
default. The consequential cases are the tokens whose values differ by ``RUN``,
for example ``@[CICE_HIST_AVG]``, which ``parsing_namelists_cice.sh`` sets to
``.false.`` for ``gdas`` because data assimilation needs instantaneous history,
and to ``.true.`` for the long ``gfs`` forecast. Dropping that token gives a DA
cycle time-averaged sea ice history with no error message.

A token whose variable is *undefined* behaves differently: the forecast job runs
under ``set -u``, so ``atparse`` aborts. Misspelling a token name is loud;
removing one is not.

Files that cannot be overridden this way
""""""""""""""""""""""""""""""""""""""""

``input.nml`` and ``diag_table`` each hold both FV3 and MOM6 content, because FMS
opens one of each by name from the run directory on behalf of the whole
executable. There is no ``MOM6/input.nml`` that MOM6 would find. MOM6's share of
``input.nml`` is the ``&MOM_input_nml`` group, and its share of ``diag_table`` is
the ``"ocean_model"`` and ``"ocean_model_z"`` lines.

``MOM_layout``, ``MOM_override`` and ``MOM_channels`` are staged from
``${FIXglobal}/mom6/${OCNRES}`` and are covered by the fix file overrides, not by
the variables above. Note that MOM6 never reads ``MOM_layout`` at all: it opens
only the files listed in ``parameter_filename`` in ``&MOM_input_nml``, which are
``MOM_input`` and ``MOM_override``. Settings intended for ``MOM_layout`` belong
in ``MOM_override`` as ``#override`` directives.

``ufs.configure`` describes the whole coupled component graph rather than any one
component. It already honors a ``ufs_configure_template`` override set in
``$EXPDIR/config.ufs``, but that is not reachable from the experiment YAML.
