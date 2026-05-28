struct bboxDataTools_v
(
    /* Sort float ascending.
       Helper method for qsort. */
    function sortFloatAscending first_value second_value =
    (
        if first_value < second_value then
        (
            -1
        )
        else if first_value > second_value then
        (
            1
        )
        else
        (
            0
        )
        -- return
    ),


    /* Get median value from float array.
       Returns 0.0 when array is empty. */
    function getMedianFromFloatArray value_array =
    (
        value_count = value_array.count

        if value_count == 0 then
        (
            0.0
        )
        else
        (
            qsort value_array sortFloatAscending

            middle_index = ((value_count + 1) / 2) as integer

            if (mod value_count 2) == 1 then
            (
                value_array[middle_index]
            )
            else
            (
                (value_array[middle_index] + value_array[middle_index + 1]) / 2.0
            )
        )
        -- return
    ),


    /* Get bbox data of single node.
       Returns #(bbox_size, bbox_center). */
    function getNodeBBoxData node_item =
    (
        if isValidNode node_item then
        (
            node_box = nodeGetBoundingBox node_item (matrix3 1)
            bbox_min = node_box[1]
            bbox_max = node_box[2]

            bbox_size = bbox_max - bbox_min
            bbox_center = (bbox_min + bbox_max) / 2.0

            #([abs bbox_size.x, abs bbox_size.y, abs bbox_size.z], bbox_center)
        )
        else
        (
            #([0, 0, 0], [0, 0, 0])
        )
        -- return
    ),


    /* Get average bbox size and center from nodes array.
       Returns #(bbox_size, bbox_center). */
    function getAverageBBoxData nodes_array =
    (
        size_sum = [0, 0, 0]
        center_sum = [0, 0, 0]
        valid_count = 0

        for node_item in nodes_array where isValidNode node_item do
        (
            node_data = getNodeBBoxData node_item

            size_sum += node_data[1]
            center_sum += node_data[2]
            valid_count += 1
        )

        if valid_count > 0 then
        (
            #((size_sum / valid_count), (center_sum / valid_count))
        )
        else
        (
            #([0, 0, 0], [0, 0, 0])
        )
        -- return
    ),


    /* Get median bbox size and center from nodes array.
       Returns #(bbox_size, bbox_center). */
    function getMedianBBoxData nodes_array =
    (
        size_x_array = #()
        size_y_array = #()
        size_z_array = #()

        center_x_array = #()
        center_y_array = #()
        center_z_array = #()

        for node_item in nodes_array where isValidNode node_item do
        (
            node_data = getNodeBBoxData node_item
            bbox_size = node_data[1]
            bbox_center = node_data[2]

            append size_x_array bbox_size.x
            append size_y_array bbox_size.y
            append size_z_array bbox_size.z

            append center_x_array bbox_center.x
            append center_y_array bbox_center.y
            append center_z_array bbox_center.z
        )

        median_size = [
            getMedianFromFloatArray size_x_array,
            getMedianFromFloatArray size_y_array,
            getMedianFromFloatArray size_z_array]

        median_center = [
            getMedianFromFloatArray center_x_array,
            getMedianFromFloatArray center_y_array,
            getMedianFromFloatArray center_z_array]

        #(median_size, median_center)
        -- return
    ),

    on create do
    (
    )
)

bboxDataTools = bboxDataTools_v()