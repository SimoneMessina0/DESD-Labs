library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity depacketizer is
    generic (
        HEADER: INTEGER :=16#FF#;
        FOOTER: INTEGER :=16#F1#
    );
    port (
        clk   : in std_logic;
        aresetn : in std_logic;

        s_axis_tdata  : in std_logic_vector(7 downto 0);
        s_axis_tvalid : in std_logic;
        m_axis_tready : in std_logic;


        s_axis_tready : out std_logic;
        m_axis_tdata  : out std_logic_vector(7 downto 0);
        m_axis_tvalid : out std_logic;
        m_axis_tlast  : out std_logic

    );
end entity depacketizer;

architecture rtl of depacketizer is

    --FSM STATES DESCRIPTION
    --HEADER_RECEIVE : the depacketizer waits for the header coming from the UART module
    --SENDING_DATA   : the depacketizer has received the header and transfers data to the RGB2GRAY
    --FOOTER_RECEIVE : the depacketizer has received the footer from the UART module so it sends the last data and 
    --                 then stops the communication 
    type fsm_state is (header_receive, sending_data, footer_receive);
    signal state : fsm_state := header_receive; 

    --Since we do not want to lose or send more data than the one of the packet, the incoming data 
    --is buffered so that when the footer arrives we send out and maintain the valid buffered data.
    --data_buffer_1 and data_buffer_2 are buffers used to implement this type of logic
    signal data_buffer_1 : std_logic_vector(7 downto 0) := (others=>'0'); 
    signal data_buffer_2 : std_logic_vector(7 downto 0) := (others=>'0');
    
begin

    process(clk,aresetn)
    begin
        if aresetn = '0' then 
            
            state           <= header_receive;
            s_axis_tready   <= '0'; 
            m_axis_tdata    <= (others =>'0');
            m_axis_tvalid   <= '0'; 
            m_axis_tlast    <= '0'; 
            data_buffer_1   <= (others => '0');
            data_buffer_2   <= (others => '0'); 

        elsif rising_edge(clk) then

            --The depacketizer is ready to receive data when 
            --the RGB2GRAY is ready to accept it so
                if m_axis_tready = '1' then
                    --if the RGB2GRAY is ready also the depacketizer is ready to receive data
                    s_axis_tready <= '1'; 
                else 
                    --otherwise the depacketizer can't receive data
                    s_axis_tready <= '0'; 
                end if; 

            case (state) is 
                when header_receive =>

                    --If the data is valid, the RGB2GRAY is ready and the UART is sending a packet
                    --the HEADER of is removed by moving to the valid_data state and not 
                    --not sending the incoming information (so the header) to the RGB2GRAY 
                    if (s_axis_tdata = std_logic_vector(to_unsigned(HEADER,8)) and s_axis_tvalid = '1' and m_axis_tready = '1') then
                        state <= sending_data;
                    else
                        --Otherwise since the depacketizer isn't sending valid data, the TVALID is kept to 0
                        m_axis_tvalid <= '0'; 
                        --and it waits in the header receive state 
                        state <= header_receive; 
                    end if; 

                when sending_data => 
                    
                    --The data is buffered  
                        data_buffer_2 <= s_axis_tdata; 
                        data_buffer_1 <= data_buffer_2;

                    ------------------------------------------------------------
                    --                  DATA TRANSFER LOGIC             
                    ------------------------------------------------------------

                    --When the MASTER data is valid and the RGB2GRAY is ready to accept data
                    --the transfer happens 
                    if s_axis_tvalid = '1' and m_axis_tready = '1' then

                        --If the data is the HEADER then it is buffered and the state is the same
                        if to_integer(unsigned(s_axis_tdata)) = HEADER then
                            state <= sending_data; 

                        --If the data is the FOOTER then 
                            --the TLAST is risen because it's the last bit of valid information
                            --the TVALID is risen because the buffer still has bits of valid information that 
                                --are being transferred to the slave
                            --the TREADY is set to 0 because it has been chosed that after a valid transfer at least one cycle is waited 
                            --since the footer has been received the packet has ended and the state is moved to the footer_received state
                        elsif to_integer(unsigned(s_axis_tdata)) = FOOTER then
                            m_axis_tlast    <= '1'; 
                            m_axis_tdata    <= data_buffer_1;  
                            m_axis_tvalid   <= '1';
                            s_axis_tready   <= '0'; 
                            state           <= footer_receive; 
                        else
                            --If the data is nor FOOTER nor HEADER then it's the packet content 
                            --and is sent to the RGB2GRAY
                            if not(data_buffer_1 = std_logic_vector(to_unsigned(HEADER,8))) then
                                --If some elaboration had already been executed, the TLAST would still be one so it's reset here 
                                m_axis_tlast    <= '0';  
                                m_axis_tdata    <= data_buffer_1; 
                                m_axis_tvalid   <= '1';
                                s_axis_tready   <= '0';
                                state           <= sending_data;
                            end if; 
                        end if; 
                    else
                    --Otherwise there's no valid data so the TVALID is reset 
                        m_axis_tvalid <= '0'; 
                    end if;

                when footer_receive =>

                    --The depacketizer does not have anymore valid data so the TVALID is reset 
                    m_axis_tvalid <= '0';

                    --The state is set to header_receive for a new execution
                    --The output of the depacketizer is kept at the last valid data of the packet
                        state <= header_receive;
                        m_axis_tdata <= data_buffer_1;       

            end case;      
        end if; 
    end process; 

end architecture;
