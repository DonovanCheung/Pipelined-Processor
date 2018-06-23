/**********************************************************************/
/*   ____  ____                                                       */
/*  /   /\/   /                                                       */
/* /___/  \  /                                                        */
/* \   \   \/                                                       */
/*  \   \        Copyright (c) 2003-2009 Xilinx, Inc.                */
/*  /   /          All Right Reserved.                                 */
/* /---/   /\                                                         */
/* \   \  /  \                                                      */
/*  \___\/\___\                                                    */
/***********************************************************************/

#include "xsi.h"

struct XSI_INFO xsi_info;



int main(int argc, char **argv)
{
    xsi_init_design(argc, argv);
    xsi_register_info(&xsi_info);

    xsi_register_min_prec_unit(-12);
    work_m_00000000000759135583_3417504961_init();
    work_m_00000000003715483201_0116421628_init();
    work_m_00000000000193507221_0177909853_init();
    work_m_00000000002567838894_1387504933_init();
    work_m_00000000002732707248_2879274177_init();
    work_m_00000000002732707248_0611318857_init();
    work_m_00000000003976491481_1306721680_init();
    work_m_00000000004134447467_2073120511_init();


    xsi_register_tops("work_m_00000000003976491481_1306721680");
    xsi_register_tops("work_m_00000000004134447467_2073120511");


    return xsi_run_simulation(argc, argv);

}
