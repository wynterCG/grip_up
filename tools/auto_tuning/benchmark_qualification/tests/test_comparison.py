import copy,json,math,struct,sys,unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from comparison import semantic,support_identity_map,audit_cursor,compare_cursor_streams,compare_required,earliest_difference,FRAME_FIELDS
from projection_comparison import strict_difference


def cursor_row(raw=None,actual=None,tick=1,valid=True):
    # R2 tick55 raw audit SHA256 6c77b42a1c0e89276ee00a4b369ac50bec76a92b3841af4cd9013859f5c30456.
    raw=[969.623779296875,480.534973144531] if raw is None else raw
    actual=[struct.unpack('<f',struct.pack('<f',x))[0] for x in raw] if actual is None else actual
    frame={'aim_valid':valid,'aim_position_viewport_px':raw}
    return {'tick':tick,'canonical_input':{'requested':copy.deepcopy(frame),'effective':copy.deepcopy(frame),'effective_aim_px':actual}}


def full_row(tick=1):
    row=cursor_row(tick=tick)
    for frame in [row['canonical_input']['requested'],row['canonical_input']['effective']]:
        frame.update({key:0 for key in FRAME_FIELDS if key not in frame})
        frame.update(schema_version='grip_input_frame_v1',focus_policy_state='ACTIVE',button_edges=[],action_edges=[])
    row.update(sample_phase='post_control',physics_hz=120,delta_s=1/120,physics_time_s=tick/120,
               command_accepted={'intent_world':[1.,0.,0.],'hand_held':[True,True]},camera={'pose':[0.,0.,0.]},
               body={'com_m':[0.,0.,0.],'pose':[0.,0.,0.],'linear_velocity_m_s':[0.,0.,0.],
                     'angular_velocity_rad_s':[0.,0.,0.],'mass_kg':12.,'contacts':[]},
               hands=[],feet=[],support={'ids':[]},contact_events=[],configuration={},frame={},target={},
               force_budget={'hands_n':0.,'feet_n':0.,'assist_nm':[0.,0.,0.],'combined_nm':[0.,0.,0.],
                             'ground_force_n':[0.,0.,0.],'ground_torque_nm':[0.,0.,0.]})
    row['benchmark_extra']={key:0 for key in ['requested_input','applied_input','applied_world','planned_arm_rest_lengths','target_rates','target_accelerations','actuator_saturated','ground_state','motor_authority','native_ground_authority','foot_compressive_load_n','ground_clearance_status','input_frame_id','input_timestamp','movement_block_reason']}
    row['benchmark_extra']['ground_state']={}
    return row


def paired(left,right,probe=False):
    audits={'left':{'frames':[r.get('canonical_input',{}).get('requested',{}) for r in left],'ticks':left},
            'right':{'frames':[r.get('canonical_input',{}).get('requested',{}) for r in right],'ticks':right}}
    manifest={'physics_hz':120,'scenario_ids':['synthetic'],'input_lane':'FIXED_VIRTUAL_REPLAY',
              'virtual_tape_sha256':'tape','expected_source_hashes':{'source':'same'},'engine_identity':{'sha256':'engine'}}
    result={'projection_setup':{'actual_size':[1024,576],'before_world':True},
            'environment':{'engine_binary_sha256':'engine','physics_backend':'Jolt Physics'},'scenarios':[{}]}
    def read(path):
        if path.name=='benchmark_audit.json':return audits[path.parent.name]
        if path.name=='manifest.json':return copy.deepcopy(manifest)
        if path.name=='engine_result.json':return copy.deepcopy(result)
        raise AssertionError(path)
    with patch('comparison.read_json',side_effect=read):
        return compare_required(Path('left'),Path('right'),probe=probe)

class RequiredChannels(unittest.TestCase):
    def test_process_identity_separate(self):
        a={'hands':[{'support':{'runtime_id':12,'key':'wall'}}]}
        b={'hands':[{'support':{'runtime_id':987,'key':'wall'}}]}
        self.assertEqual(support_identity_map([a])[12],support_identity_map([b])[987])
        self.assertEqual(semantic(a),semantic(b))
    def test_instance_chain_not_collapsed(self):
        rows=[{'hands':[{'support':{'runtime_id':i,'key':'wall'}}]} for i in [12,13,12]]
        m=support_identity_map(rows);self.assertNotEqual(m[12],m[13])
    def test_contact_and_applied_force_not_dropped(self):
        self.assertIsNotNone(strict_difference(semantic({'foot':{'force_n':[0,1,0]}}),semantic({'foot':{'force_n':[0,2,0]}})))
        self.assertIsNotNone(strict_difference(semantic({'rest_length_m':.6}),semantic({'rest_length_m':.61})))
        self.assertIsNotNone(strict_difference(semantic({'motor_authority':0.}),semantic({'motor_authority':1.})))
    def test_runtime_metadata_does_not_erase_semantic_shape(self):
        self.assertEqual(semantic({'runtime_id':23,'shape':1}),{'shape':1})
        self.assertIsNotNone(strict_difference(semantic({'runtime_id':1,'shape':0}),semantic({'runtime_id':2,'shape':1})))

    def test_r2_cursor_representation_preserves_raw_bits_and_native_decimal(self):
        row=cursor_row(tick=55);result=audit_cursor(row)
        self.assertEqual(result['status'],'TYPED_COORDINATE_VALID')
        self.assertTrue(result['raw_vs_actual_binary64_differs'])
        self.assertEqual(result['raw_requested'][1]['raw_binary64_le'],'fcffff3f8f087e40')
        self.assertEqual(result['actual_api_vector'][1]['raw_binary64_le'],'000000408f087e40')
        self.assertEqual(result['raw_requested'][1]['native_binary32_le'],result['actual_api_vector'][1]['native_binary32_le'])
        self.assertEqual(result['raw_requested'][1]['native_float32_decimal'],'480.53497314453125')
        self.assertEqual(compare_cursor_streams([row],[copy.deepcopy(row)])['status'],'STRICT_MATCH')

    def test_legacy_output_retained_and_disagreement_labelled(self):
        row=full_row();result=paired([row],[copy.deepcopy(row)])
        self.assertEqual(result['status'],'STRICT_MATCH')
        self.assertEqual(result['legacy_layers']['status'],'CURSOR_OR_CAMERA_MISMATCH')
        self.assertEqual(result['legacy_interpretation']['status'],'LEGACY_REPRESENTATION_SELF_COMPARISON')
        self.assertEqual(result['legacy_layers']['first_by_layer']['cursor']['tick'],1)

    def test_real_pixel_change_is_not_canonicalized_away(self):
        left=cursor_row();right=cursor_row(raw=[970.,480.534973144531])
        self.assertEqual(compare_cursor_streams([left],[right])['status'],'MISMATCH')
        right=copy.deepcopy(left);right['canonical_input']['effective_aim_px'][0]+=1.
        self.assertEqual(compare_cursor_streams([left],[right])['status'],'TYPE_REPRESENTATION_MISMATCH')

    def test_legacy_truncated_api_value_is_incomparable_not_strict(self):
        row=cursor_row(actual=[969.623779296875,480.534973144531])
        self.assertEqual(audit_cursor(row)['status'],'TYPE_REPRESENTATION_MISMATCH')
        self.assertEqual(compare_cursor_streams([row],[copy.deepcopy(row)])['status'],'TYPE_REPRESENTATION_MISMATCH')

    def test_missing_wrong_type_nonfinite_and_overflow_invalid(self):
        for value in (None,[1.],[1.,2.,3.],[True,0.],['1',0.],[math.nan,0.],[math.inf,0.],[1e99,0.]):
            row=cursor_row();row['canonical_input']['requested']['aim_position_viewport_px']=value
            self.assertEqual(audit_cursor(row)['status'],'INVALID_SCHEMA',value)
        row=cursor_row();row['canonical_input'].pop('effective_aim_px')
        self.assertEqual(audit_cursor(row)['status'],'INVALID_SCHEMA')
        self.assertEqual(compare_cursor_streams([],[])['status'],'INVALID_SCHEMA')

    def test_invalid_aim_does_not_recenter_or_use_raw_coordinate(self):
        row=cursor_row(raw=[0.,0.],actual=[100.,200.],valid=False)
        self.assertEqual(audit_cursor(row)['status'],'TYPED_COORDINATE_VALID')
        self.assertFalse(audit_cursor(row)['raw_to_actual_equivalence_applicable'])
        self.assertEqual(compare_cursor_streams([row],[copy.deepcopy(row)])['status'],'STRICT_MATCH')

    def test_signed_zero_bits_are_preserved(self):
        left=cursor_row(raw=[0.,0.],actual=[0.,0.]);right=cursor_row(raw=[-0.,0.],actual=[-0.,0.])
        self.assertNotEqual(audit_cursor(left)['raw_requested'][0]['native_binary32_le'],audit_cursor(right)['raw_requested'][0]['native_binary32_le'])
        self.assertEqual(compare_cursor_streams([left],[right])['status'],'MISMATCH')

    def test_missing_required_published_field_never_strict(self):
        for key in ('contact_events','command_accepted','canonical_input'):
            row=full_row();row.pop(key)
            self.assertEqual(paired([row],[copy.deepcopy(row)])['status'],'INVALID_SCHEMA')
        row=full_row();row['canonical_input']['effective'].pop('button_edges')
        self.assertEqual(paired([row],[copy.deepcopy(row)])['status'],'INVALID_SCHEMA')
        row=full_row();row['body'].pop('mass_kg')
        self.assertEqual(paired([row],[copy.deepcopy(row)])['status'],'INVALID_SCHEMA')

    def test_earliest_tick_wins_over_layer_order_and_later_physics_is_retained(self):
        left=[full_row(i) for i in range(1,5)];right=copy.deepcopy(left)
        right[1]['force_budget']['hands_n']=1.
        right[3]['benchmark_extra']['applied_world']=1.
        result=paired(left,right)
        self.assertEqual(result['status'],'MISMATCH')
        self.assertEqual(result['first_difference']['layer'],'PHYSICS')
        self.assertEqual(result['first_difference']['tick'],2)
        right=copy.deepcopy(left);right[0]['benchmark_extra']['applied_world']=1.;right[2]['body']['com_m'][0]=.000000000001
        result=paired(left,right)
        self.assertEqual(result['first_difference']['layer'],'INPUT')
        self.assertEqual(result['first_difference']['tick'],1)
        self.assertEqual(result['first_actual_physics_divergence']['tick'],3)
        self.assertEqual(result['first_later_physics_divergence']['tick'],3)

    def test_contact_event_is_required_measured_channel(self):
        left=[full_row()];right=copy.deepcopy(left)
        right[0]['contact_events']=[{'code':'CONTACT','tick':1}]
        result=paired(left,right)
        self.assertEqual(result['status'],'MISMATCH')
        self.assertEqual(result['first_by_layer']['CONTACT']['tick'],1)

    def test_contact_event_uses_episode_tick_not_preworld_callback_count(self):
        left=[full_row()];right=copy.deepcopy(left)
        left[0]['contact_events']=[{'code':'CONTACT','tick':1,'sample_phase':'pre_control','run_tick':4}]
        right[0]['contact_events']=[{'code':'CONTACT','tick':1,'sample_phase':'pre_control','run_tick':6}]
        self.assertEqual(paired(left,right)['status'],'STRICT_MATCH')
        right[0]['contact_events'][0]['sample_phase']='post_control'
        self.assertEqual(paired(left,right)['status'],'MISMATCH')

    def test_ray_material_and_body_samples_keep_exact_binary64(self):
        for field in ['material_point','world_ray_normal','com_m']:
            self.assertIsNotNone(strict_difference({field:[1.,0.,0.]},{field:[math.nextafter(1.,2.),0.,0.]}))

    def test_point_of_call_earlier_difference_is_not_hidden_by_later_input(self):
        left=[full_row(i) for i in range(1,5)];right=copy.deepcopy(left)
        right[3]['benchmark_extra']['applied_world']=1.
        with patch('comparison.projection_pair',return_value={'status':'STRICT_MISMATCH','first_by_stage':{'world_ray':{'tick':2,'difference':{'field':'ray'}}}}):
            result=paired(left,right,probe=True)
        self.assertEqual(result['first_difference']['layer'],'PICK')
        self.assertEqual(result['first_difference']['tick'],2)

    def test_point_published_physics_difference_is_not_mislabelled_as_pick(self):
        left=[full_row(i) for i in range(1,4)];right=copy.deepcopy(left)
        right[1]['body']['com_m'][0]=.00001
        point={'status':'STRICT_MISMATCH','first_by_stage':{},'published_layers':{'first_overall':{'layer':'physics','tick':2,'difference':{'field':'com'}}}}
        with patch('comparison.projection_pair',return_value=point):result=paired(left,right,probe=True)
        self.assertEqual(result['first_difference']['layer'],'PHYSICS')
        self.assertIsNone(result['first_by_layer']['PICK'])
        with patch('comparison.projection_pair',return_value=point):result=paired(left,copy.deepcopy(left),probe=True)
        self.assertEqual(result['first_difference']['layer'],'PHYSICS')
        self.assertEqual(result['first_difference']['tick'],2)

if __name__=='__main__':unittest.main()
