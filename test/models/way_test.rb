require "test_helper"

class WayTest < ActiveSupport::TestCase
  def test_bbox
    node = create(:node)
    visible_way = create(:way)
    create(:way_node, :way => visible_way, :node => node)
    invisible_way = create(:way, :deleted)
    create(:way_node, :way => invisible_way, :node => node)
    used_way = create(:way)
    create(:way_node, :way => used_way, :node => node)
    create(:relation_member, :member => used_way)

    [visible_way, invisible_way, used_way].each do |way|
      assert_equal node.bbox.min_lon, way.bbox.min_lon, "min_lon"
      assert_equal node.bbox.min_lat, way.bbox.min_lat, "min_lat"
      assert_equal node.bbox.max_lon, way.bbox.max_lon, "max_lon"
      assert_equal node.bbox.max_lat, way.bbox.max_lat, "max_lat"
    end
  end

  # Check that the preconditions fail when you are over the defined limit of
  # the maximum number of nodes in each way.
  def test_max_nodes_per_way_limit
    node_a = create(:node)
    node_b = create(:node)
    node_c = create(:node)
    way = create(:way_with_nodes, :nodes_count => 1)
    # Take one of the current ways and add nodes to it until we are near the limit
    assert_predicate way, :valid?
    # it already has 1 node
    1.upto(Settings.max_number_of_way_nodes / 2) do
      way.add_nd_num(node_a.id)
      way.add_nd_num(node_b.id)
    end
    way.save
    assert_predicate way, :valid?
    way.add_nd_num(node_c.id)
    assert_predicate way, :valid?
  end

  def test_from_xml_no_id
    noid = "<osm><way version='12' changeset='23' /></osm>"
    assert_nothing_raised do
      Way.from_xml(noid, :create => true)
    end
    message = assert_raise(OSM::APIBadXMLError) do
      Way.from_xml(noid, :create => false)
    end
    assert_match(/ID is required when updating/, message.message)
  end

  def test_from_xml_no_changeset_id
    nocs = "<osm><way id='123' version='23' /></osm>"
    message_create = assert_raise(OSM::APIBadXMLError) do
      Way.from_xml(nocs, :create => true)
    end
    assert_match(/Changeset id is missing/, message_create.message)
    message_update = assert_raise(OSM::APIBadXMLError) do
      Way.from_xml(nocs, :create => false)
    end
    assert_match(/Changeset id is missing/, message_update.message)
  end

  def test_from_xml_no_version
    no_version = "<osm><way id='123' changeset='23' /></osm>"
    assert_nothing_raised do
      Way.from_xml(no_version, :create => true)
    end
    message_update = assert_raise(OSM::APIBadXMLError) do
      Way.from_xml(no_version, :create => false)
    end
    assert_match(/Version is required when updating/, message_update.message)
  end

  def test_from_xml_id_zero
    id_list = ["", "0", "00", "0.0", "a"]
    id_list.each do |id|
      zero_id = "<osm><way id='#{id}' changeset='33' version='23' /></osm>"
      assert_nothing_raised do
        Way.from_xml(zero_id, :create => true)
      end
      message_update = assert_raise(OSM::APIBadUserInput) do
        Way.from_xml(zero_id, :create => false)
      end
      assert_match(/ID of way cannot be zero when updating/, message_update.message)
    end
  end

  def test_from_xml_no_text
    no_text = ""
    message_create = assert_raise(OSM::APIBadXMLError) do
      Way.from_xml(no_text, :create => true)
    end
    assert_match(/Must specify a string with one or more characters/, message_create.message)
    message_update = assert_raise(OSM::APIBadXMLError) do
      Way.from_xml(no_text, :create => false)
    end
    assert_match(/Must specify a string with one or more characters/, message_update.message)
  end

  def test_from_xml_no_k_v
    nokv = "<osm><way id='23' changeset='23' version='23'><tag /></way></osm>"
    message_create = assert_raise(OSM::APIBadXMLError) do
      Way.from_xml(nokv, :create => true)
    end
    assert_match(/tag is missing key/, message_create.message)
    message_update = assert_raise(OSM::APIBadXMLError) do
      Way.from_xml(nokv, :create => false)
    end
    assert_match(/tag is missing key/, message_update.message)
  end

  def test_from_xml_no_v
    no_v = "<osm><way id='23' changeset='23' version='23'><tag k='key' /></way></osm>"
    message_create = assert_raise(OSM::APIBadXMLError) do
      Way.from_xml(no_v, :create => true)
    end
    assert_match(/tag is missing value/, message_create.message)
    message_update = assert_raise(OSM::APIBadXMLError) do
      Way.from_xml(no_v, :create => false)
    end
    assert_match(/tag is missing value/, message_update.message)
  end

  def test_from_xml_duplicate_k
    dupk = "<osm><way id='23' changeset='23' version='23'><tag k='dup' v='test' /><tag k='dup' v='tester' /></way></osm>"
    message_create = assert_raise(OSM::APIDuplicateTagsError) do
      Way.from_xml(dupk, :create => true)
    end
    assert_equal "Element way/ has duplicate tags with key dup", message_create.message
    message_update = assert_raise(OSM::APIDuplicateTagsError) do
      Way.from_xml(dupk, :create => false)
    end
    assert_equal "Element way/23 has duplicate tags with key dup", message_update.message
  end

  def test_way_nodes
    way = create(:way)
    node1 = create(:way_node, :way => way, :sequence_id => 1).node
    node2 = create(:way_node, :way => way, :sequence_id => 2).node
    node3 = create(:way_node, :way => way, :sequence_id => 3).node

    nodes = Way.find(way.id).way_nodes
    assert_equal 3, nodes.count
    assert_equal node1.id, nodes[0].node_id
    assert_equal node2.id, nodes[1].node_id
    assert_equal node3.id, nodes[2].node_id
  end

  def test_nodes
    way = create(:way)
    node1 = create(:way_node, :way => way, :sequence_id => 1).node
    node2 = create(:way_node, :way => way, :sequence_id => 2).node
    node3 = create(:way_node, :way => way, :sequence_id => 3).node

    nodes = Way.find(way.id).nodes
    assert_equal 3, nodes.count
    assert_equal node1.id, nodes[0].id
    assert_equal node2.id, nodes[1].id
    assert_equal node3.id, nodes[2].id
  end

  def test_nds
    way = create(:way)
    node1 = create(:way_node, :way => way, :sequence_id => 1).node
    node2 = create(:way_node, :way => way, :sequence_id => 2).node
    node3 = create(:way_node, :way => way, :sequence_id => 3).node

    nodes = Way.find(way.id).nds
    assert_equal 3, nodes.count
    assert_equal node1.id, nodes[0]
    assert_equal node2.id, nodes[1]
    assert_equal node3.id, nodes[2]
  end

  def test_way_tags
    way = create(:way)
    taglist = create_list(:way_tag, 2, :way => way)
    tags = Way.find(way.id).way_tags.order(:k)
    assert_equal taglist.count, tags.count
    taglist.sort_by!(&:k).each_index do |i|
      assert_equal taglist[i].k, tags[i].k
      assert_equal taglist[i].v, tags[i].v
    end
  end

  def test_tags
    way = create(:way)
    taglist = create_list(:way_tag, 2, :way => way)
    tags = Way.find(way.id).tags
    assert_equal taglist.count, tags.count
    taglist.each do |tag|
      assert_equal tag.v, tags[tag.k]
    end
  end

  def test_containing_relation_members
    way = create(:way)
    relation = create(:relation)
    create(:relation_member, :relation => relation, :member => way)

    crm = Way.find(way.id).containing_relation_members.order(:relation_id)
    #    assert_equal 1, crm.size
    assert_equal relation.id, crm.first.relation_id
    assert_equal "Way", crm.first.member_type
    assert_equal way.id, crm.first.member_id
    assert_equal relation.id, crm.first.relation.id
  end

  def test_containing_relations
    way = create(:way)
    relation = create(:relation)
    create(:relation_member, :relation => relation, :member => way)

    cr = Way.find(way.id).containing_relations.order(:id)
    assert_equal 1, cr.size
    assert_equal relation.id, cr.first.id
  end

  test "raises missing changeset exception when creating" do
    user = create(:user)
    way = Way.new
    assert_raises OSM::APIChangesetMissingError do
      way.create_with_history(user)
    end
  end

  test "raises user-changeset mismatch exception when creating" do
    user = create(:user)
    changeset = create(:changeset)
    way = Way.new(:changeset => changeset)
    assert_raises OSM::APIUserChangesetMismatchError do
      way.create_with_history(user)
    end
  end

  test "raises already closed changeset exception when creating" do
    user = create(:user)
    changeset = create(:changeset, :closed, :user => user)
    way = Way.new(:changeset => changeset)
    assert_raises OSM::APIChangesetAlreadyClosedError do
      way.create_with_history(user)
    end
  end

  test "raises id precondition exception when updating" do
    user = create(:user)
    way = Way.new(:id => 23)
    new_way = Way.new(:id => 42)
    assert_raises OSM::APIPreconditionFailedError do
      way.update_from(new_way, user)
    end
  end

  test "raises version mismatch exception when updating" do
    user = create(:user)
    way = Way.new(:id => 42, :version => 7)
    new_way = Way.new(:id => 42, :version => 12)
    assert_raises OSM::APIVersionMismatchError do
      way.update_from(new_way, user)
    end
  end

  test "raises missing changeset exception when updating" do
    user = create(:user)
    way = Way.new(:id => 42, :version => 12)
    new_way = Way.new(:id => 42, :version => 12)
    assert_raises OSM::APIChangesetMissingError do
      way.update_from(new_way, user)
    end
  end

  test "raises user-changeset mismatch exception when updating" do
    user = create(:user)
    changeset = create(:changeset)
    way = Way.new(:id => 42, :version => 12)
    new_way = Way.new(:id => 42, :version => 12, :changeset => changeset)
    assert_raises OSM::APIUserChangesetMismatchError do
      way.update_from(new_way, user)
    end
  end

  test "raises already closed changeset exception when updating" do
    user = create(:user)
    changeset = create(:changeset, :closed, :user => user)
    way = Way.new(:id => 42, :version => 12)
    new_way = Way.new(:id => 42, :version => 12, :changeset => changeset)
    assert_raises OSM::APIChangesetAlreadyClosedError do
      way.update_from(new_way, user)
    end
  end

  test "raises id precondition exception when deleting" do
    user = create(:user)
    way = Way.new(:id => 23, :visible => true)
    new_way = Way.new(:id => 42, :visible => false)
    assert_raises OSM::APIPreconditionFailedError do
      way.delete_with_history!(new_way, user)
    end
  end
end
