from PIL import Image


def main():
    return None


def daq_to_bytes( img_dir ):
    
    f = open( img_dir, 'rb' )

    b = f.read()

    return b


def display_bytes( byte_obj ):

    b_info = byte_obj[:12]

    rows = int( b_info[0] )*16*16 + int( b_info[1] ) + 1

    columns = int( b_info[2] )*16*16 + int( b_info[3] ) + 1

    im = Image.frombytes( 'P', ( columns, rows ), byte_obj, 'raw' )
    im.show()

    return None


def display_gif( img_dir ):

    im = Image.open( img_dir )
    im.show()

    return None


if __name__ == '__main__':
    main()
