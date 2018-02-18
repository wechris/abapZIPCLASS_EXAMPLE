*&---------------------------------------------------------------------*
*& Report ZABAP_ZIP_EXAMPLE
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT ZABAP_ZIP_EXAMPLE.

CLASS: GCL_DATA_PROCESS DEFINITION DEFERRED.



DATA: GO_DATA_PROC  TYPE REF TO GCL_DATA_PROCESS.



*----------------------------------------------------------------------*

*       CLASS gcl_data_process DEFINITION

*----------------------------------------------------------------------*

CLASS GCL_DATA_PROCESS DEFINITION.



  PUBLIC SECTION.



    METHODS:

*   Instance class constructor

      CONSTRUCTOR

        EXCEPTIONS

          EX_FILE_SEL_ERR

          EX_FILE_UPLOAD,



*   Zip the files

      ZIP_FILE

        EXCEPTIONS

          EX_BIN_CONV_ERROR

          EX_ZIP_ERROR,



*   Download the Zip file to the PC folder

      DOWNLOAD_FILE

        EXPORTING

          Y_FILESIZE TYPE I

        EXCEPTIONS

          EX_DWLD_ERROR.



  PRIVATE SECTION.



    TYPES:



      BEGIN OF PS_BIN_FILE,

        NAME TYPE STRING,

        SIZE TYPE I,

        DATA TYPE SOLIX_TAB,

      END OF PS_BIN_FILE.



    DATA: PT_BINDATA       TYPE STANDARD TABLE OF PS_BIN_FILE,

          PT_FILETAB       TYPE FILETABLE,

          PV_DEST_FILEPATH TYPE STRING,

          PT_ZIP_BIN_DATA  TYPE STANDARD TABLE OF RAW255,

          PV_ZIP_SIZE      TYPE I.



    METHODS:

*   Select the files to be zipped

      SELECT_FILES

        EXCEPTIONS

          EX_FILE_SEL_ERR,



*   Select the destination file

      SAVE_FILE_DIALOG.



ENDCLASS.                    "gcl_data_process DEFINITION



*----------------------------------------------------------------------*

*       CLASS gcl_data_process IMPLEMENTATION

*----------------------------------------------------------------------*

CLASS GCL_DATA_PROCESS IMPLEMENTATION.



  METHOD SELECT_FILES.



    DATA: LV_RET_CODE TYPE I,

          LV_USR_AXN  TYPE I.



    CL_GUI_FRONTEND_SERVICES=>FILE_OPEN_DIALOG(

      EXPORTING

        WINDOW_TITLE            = 'Select file'

        MULTISELECTION          = 'X'

      CHANGING

        FILE_TABLE              = ME->PT_FILETAB

        RC                      = LV_RET_CODE

        USER_ACTION             = LV_USR_AXN

      EXCEPTIONS

        FILE_OPEN_DIALOG_FAILED = 1

        CNTL_ERROR              = 2

        ERROR_NO_GUI            = 3

        NOT_SUPPORTED_BY_GUI    = 4

        OTHERS                  = 5

           ).

    IF SY-SUBRC <> 0 OR

       LV_USR_AXN = CL_GUI_FRONTEND_SERVICES=>ACTION_CANCEL.

      RAISE EX_FILE_SEL_ERR.

    ENDIF.



  ENDMETHOD.                    "select_files



  METHOD CONSTRUCTOR.



    DATA: LWA_FILE    TYPE FILE_TABLE,

          LV_FILENAME TYPE STRING,

          LWA_BINDATA TYPE ME->PS_BIN_FILE.



*   Select the files

    ME->SELECT_FILES( EXCEPTIONS EX_FILE_SEL_ERR = 1 ).

    IF SY-SUBRC <> 0.

      RAISE EX_FILE_SEL_ERR.

    ENDIF.



*   Loop on the selected files & populate the internal table

    LOOP AT ME->PT_FILETAB INTO LWA_FILE.

      LV_FILENAME = LWA_FILE-FILENAME.

*     Upload the PDF data in binary format

      CL_GUI_FRONTEND_SERVICES=>GUI_UPLOAD(

        EXPORTING

          FILENAME                = LV_FILENAME

          FILETYPE                = 'BIN'

        IMPORTING

          FILELENGTH              = LWA_BINDATA-SIZE

        CHANGING

          DATA_TAB                = LWA_BINDATA-DATA

        EXCEPTIONS

          FILE_OPEN_ERROR         = 1

          FILE_READ_ERROR         = 2

          NO_BATCH                = 3

          GUI_REFUSE_FILETRANSFER = 4

          INVALID_TYPE            = 5

          NO_AUTHORITY            = 6

          UNKNOWN_ERROR           = 7

          BAD_DATA_FORMAT         = 8

          HEADER_NOT_ALLOWED      = 9

          SEPARATOR_NOT_ALLOWED   = 10

          HEADER_TOO_LONG         = 11

          UNKNOWN_DP_ERROR        = 12

          ACCESS_DENIED           = 13

          DP_OUT_OF_MEMORY        = 14

          DISK_FULL               = 15

          DP_TIMEOUT              = 16

          NOT_SUPPORTED_BY_GUI    = 17

          ERROR_NO_GUI            = 18

          OTHERS                  = 19

             ).

      IF SY-SUBRC <> 0.

        RAISE EX_FILE_UPLOAD.

      ENDIF.



*     Get the filename

      CALL FUNCTION 'SO_SPLIT_FILE_AND_PATH'
        EXPORTING
          FULL_NAME     = LV_FILENAME
        IMPORTING
          STRIPPED_NAME = LWA_BINDATA-NAME
        EXCEPTIONS
          X_ERROR       = 1
          OTHERS        = 2.

      IF SY-SUBRC <> 0.

*       SUBRC check is not reqd.

      ENDIF.



*     Add the PDF data to the internal table

      APPEND LWA_BINDATA TO ME->PT_BINDATA.



    ENDLOOP.



  ENDMETHOD.                    "constructor



  METHOD ZIP_FILE.



    DATA: LO_ZIP         TYPE REF TO CL_ABAP_ZIP,

          LV_XSTRING     TYPE XSTRING,

          LV_ZIP_XSTRING TYPE XSTRING.



    FIELD-SYMBOLS: <LWA_BINDATA> TYPE ME->PS_BIN_FILE.



    CREATE OBJECT LO_ZIP. "Create instance of Zip Class



    LOOP AT ME->PT_BINDATA ASSIGNING <LWA_BINDATA>.



*     Convert the data from Binary format to XSTRING

      CALL FUNCTION 'SCMS_BINARY_TO_XSTRING'
        EXPORTING
          INPUT_LENGTH = <LWA_BINDATA>-SIZE
        IMPORTING
          BUFFER       = LV_XSTRING
        TABLES
          BINARY_TAB   = <LWA_BINDATA>-DATA
        EXCEPTIONS
          FAILED       = 1
          OTHERS       = 2.

      IF SY-SUBRC <> 0.

        RAISE EX_BIN_CONV_ERROR.

      ENDIF.



*     Add file to the zip folder

      LO_ZIP->ADD(  NAME    = <LWA_BINDATA>-NAME

                    CONTENT = LV_XSTRING ).

    ENDLOOP.



*   Get the binary stream for ZIP file

    LV_ZIP_XSTRING = LO_ZIP->SAVE( ).



*   Convert the XSTRING to Binary table

    CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
      EXPORTING
        BUFFER        = LV_ZIP_XSTRING
      IMPORTING
        OUTPUT_LENGTH = ME->PV_ZIP_SIZE
      TABLES
        BINARY_TAB    = ME->PT_ZIP_BIN_DATA.



  ENDMETHOD.                    "zip_file

  METHOD DOWNLOAD_FILE.



    DATA: LV_DEST_PATH TYPE STRING.



*   Get the Zip filepath

    ME->SAVE_FILE_DIALOG( ).



    CHECK ME->PV_DEST_FILEPATH IS NOT INITIAL.



*   Download the Zip file

    CL_GUI_FRONTEND_SERVICES=>GUI_DOWNLOAD(

      EXPORTING

        BIN_FILESIZE              = ME->PV_ZIP_SIZE

        FILENAME                  = ME->PV_DEST_FILEPATH

        FILETYPE                  = 'BIN'

      IMPORTING

        FILELENGTH                = Y_FILESIZE

      CHANGING

        DATA_TAB                  = ME->PT_ZIP_BIN_DATA

      EXCEPTIONS

        FILE_WRITE_ERROR          = 1

        NO_BATCH                  = 2

        GUI_REFUSE_FILETRANSFER   = 3

        INVALID_TYPE              = 4

        NO_AUTHORITY              = 5

        UNKNOWN_ERROR             = 6

        HEADER_NOT_ALLOWED        = 7

        SEPARATOR_NOT_ALLOWED     = 8

        FILESIZE_NOT_ALLOWED      = 9

        HEADER_TOO_LONG           = 10

        DP_ERROR_CREATE           = 11

        DP_ERROR_SEND             = 12

        DP_ERROR_WRITE            = 13

        UNKNOWN_DP_ERROR          = 14

        ACCESS_DENIED             = 15

        DP_OUT_OF_MEMORY          = 16

        DISK_FULL                 = 17

        DP_TIMEOUT                = 18

        FILE_NOT_FOUND            = 19

        DATAPROVIDER_EXCEPTION    = 20

        CONTROL_FLUSH_ERROR       = 21

        NOT_SUPPORTED_BY_GUI      = 22

        ERROR_NO_GUI              = 23

        OTHERS                    = 24

           ).

    IF SY-SUBRC <> 0.

      RAISE EX_DWLD_ERROR.

    ENDIF.



  ENDMETHOD.                    "download_file

  METHOD SAVE_FILE_DIALOG.



    DATA: LV_FILENAME TYPE STRING,

          LV_PATH     TYPE STRING.



    CL_GUI_FRONTEND_SERVICES=>FILE_SAVE_DIALOG(

      EXPORTING

        WINDOW_TITLE         = 'Select the File Save Location'

        FILE_FILTER = '(*.zip)|*.zip|'

      CHANGING

        FILENAME             = LV_FILENAME

        PATH                 = LV_PATH

        FULLPATH             = ME->PV_DEST_FILEPATH

      EXCEPTIONS

        CNTL_ERROR           = 1

        ERROR_NO_GUI         = 2

        NOT_SUPPORTED_BY_GUI = 3

        OTHERS               = 4

           ).

    IF SY-SUBRC <> 0.

*     SUBRC check is not reqd.

    ENDIF.



  ENDMETHOD.                    "save_file_dialog



ENDCLASS.                    "gcl_data_process IMPLEMENTATION



START-OF-SELECTION.



* Get the local instance of file processing class

  CREATE OBJECT GO_DATA_PROC
    EXCEPTIONS
      EX_FILE_SEL_ERR = 1
      EX_FILE_UPLOAD  = 2.



  IF SY-SUBRC <> 0.

    MESSAGE 'Error Uploading files' TYPE 'I'.

    LEAVE LIST-PROCESSING.

  ENDIF.



* Add the selected files to the ZIP folder

  GO_DATA_PROC->ZIP_FILE(

  EXCEPTIONS

    EX_BIN_CONV_ERROR = 1

    EX_ZIP_ERROR = 2  ).



  IF SY-SUBRC <> 0.

    MESSAGE 'Error Zipping the files' TYPE 'I'.

    LEAVE LIST-PROCESSING.

  ENDIF.



END-OF-SELECTION.



  DATA: GV_FILESIZE TYPE I.



* Download the file to the selected folder

  GO_DATA_PROC->DOWNLOAD_FILE(

    IMPORTING

      Y_FILESIZE = GV_FILESIZE

    EXCEPTIONS

      EX_DWLD_ERROR = 1 ).

  IF SY-SUBRC <> 0.

    MESSAGE 'Error downloading the Zip file' TYPE 'E'.

  ELSE.

    MESSAGE S000(YKG_TEST) WITH GV_FILESIZE 'bytes downloaded'(001).

  ENDIF.
