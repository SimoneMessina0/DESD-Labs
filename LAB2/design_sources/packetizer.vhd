library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity packetizer is
    generic (
        HEADER: INTEGER :=16#FF#;
        FOOTER: INTEGER :=16#F1#
    );
    port (
        clk   : in std_logic;
        aresetn : in std_logic;

        s_axis_tdata : in std_logic_vector(7 downto 0);
        s_axis_tvalid : in std_logic; 
        s_axis_tready : out std_logic; 
        s_axis_tlast : in std_logic;

        m_axis_tdata : out std_logic_vector(7 downto 0);
        m_axis_tvalid : out std_logic; 
        m_axis_tready : in std_logic

    );
end entity packetizer;

architecture rtl of packetizer is

    --FSM STATES DESCRIPTION
    -- HEADER_HANDHSKE  : the packetizer waits valid data from the convolution 
    -- SENDING_DATA     : the packetizer has received the HEADER and now sends the data
    -- FOOTER_HANDSHAKE : the packetizer has sent all the packet data and appends the FOOTER
    type fsm_state is (header_handshake, sending_data, footer_handshake);
    signal state : fsm_state := header_handshake; 
    
    --Signal to manage the TVALID in the FSM in order to avoid multiple drive error on the m_axis_tvalid pin 
    signal valid_reg : std_logic := '0'; 

    --Signal to be able to read the s_axis_tready state
    signal s_axis_tready_readable : std_logic := '0'; 
    signal footer_stall : std_logic := '0';

begin

    --To properly manage the TVALID in order to rise it as soon as we have valid data, the 
    --m_axis_tvalid logic has been implemented partially with a mux here and a signal managed in the FSM process
    --
    --The first statement refers to the HEADER appending to the datapack, as soon as we receive valid data from
    --the convolution module we rise the TVALID to send out the header
    --
    --The second statement refers to the first bit of the datapack, in order to rise the TVALID as soon as we have valid 
    --data, while in the other part of the datapack the TVALID is managed by the valid_reg value of the FSM
    --
    --The third statement refers to the TVALID logic for the FOOTER appending, as soon as the footer has to be 
    --appended to the datapack the TVALID is risen 
    m_axis_tvalid <= '1' when (state = header_handshake and s_axis_tvalid = '1' and m_axis_tready = '1' and aresetn = '1') 
    
                           or (state = sending_data and s_axis_tvalid = '0' and s_axis_tready_readable = '0') 
                                                                                                    
                           or (state = footer_handshake and s_axis_tvalid = '0' and s_axis_tlast = '1' and m_axis_tready = '1' and footer_stall = '1')    else                                                                     
                     valid_reg; 

    --Assignment of the signal to manage and read the TREADY of the packetizer
    s_axis_tready <= s_axis_tready_readable;

    process(clk,aresetn)
    begin
        if aresetn = '0' then 
            
            m_axis_tdata             <= (others => '0'); 
            valid_reg                <= '0';
            s_axis_tready_readable   <= '0'; 
            state                    <= header_handshake;

        elsif rising_edge(clk) then

            case (state) is 

                when header_handshake =>
                    --as soon as the UART is ready to receive data, the packetizer is ready to send it
                    if m_axis_tready = '1' then
                        s_axis_tready_readable <= '1';
                    end if; 
                    m_axis_tdata <= std_logic_vector(to_unsigned(HEADER,8));

                    --after the HEADER has been sent, the packetizer is ready to send out the data coming from the 
                    --convolution module so it moves to the SENDING_DATA state
                    if s_axis_tvalid = '1' and m_axis_tready = '1' then
                        state <= sending_data;
                        --The TREADY is reset because the first bit still must be sent, so the packetizer informs
                        --the convolution module that it is not ready to receive new data, since it still has to 
                        --send out the first bit it received from the rising edge of the TVALID
                        s_axis_tready_readable <= '0'; 
                        m_axis_tdata <= s_axis_tdata; 
                    else
                        valid_reg <= '0'; 
                    end if; 


                when sending_data => 
                    m_axis_tdata <= s_axis_tdata; 

                    --When the UART is ready to receive data then also the packetizer is ready 
                    if m_axis_tready = '1' then
                        s_axis_tready_readable <= '1'; 
                    else
                    --otherwise if the UART is not ready, the packetizer must inform the convolution
                    --module that it is NOT READY to receive more data
                        s_axis_tready_readable <= '0'; 
                    end if; 

                    --If the packetizer is ready to send out data the TVALID is risen and it has been chosen that 
                    --the TREADY will be down for at least one cycle after a valid data trasnfer 
                    if s_axis_tvalid = '1' and s_axis_tready_readable = '1' then
                        valid_reg <= '1';
                        state <= sending_data;
                        s_axis_tready_readable <= '0';
                        if s_axis_tlast = '1' then
                            --As soon as the packetizer receives the TLAST it is ready to append the FOOTER
                            state <= footer_handshake;
                        end if;
                    else
                    --Otherwise since the packetizer does not have valid data, TVALID is reset 
                        valid_reg <= '0'; 
                    end if; 
                
                when footer_handshake =>

                    --The FOOTER is set on the output port 
                    m_axis_tdata <= std_logic_vector(to_unsigned(FOOTER,8));
                    s_axis_tready_readable <= '0';
                    --valid_reg is reset in order to let the MUX manage the TVALID
                    valid_reg    <= '0'; 
                    -- The footer_stall is used to avoid misreading the m_axis_tready from the last byte of the packet
                    if footer_stall = '0' then
                        footer_stall <='1';
                    elsif m_axis_tready = '1' then 
                        state <= header_handshake; 
                        footer_stall <= '0';
                    end if; 
            end case; 

        end if; 
    end process; 
end architecture;
